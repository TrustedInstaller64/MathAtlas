import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ProblemEditorView: View {
    @Environment(ProblemStore.self) private var store
    @Environment(LocaleManager.self) private var locale
    let problem: Problem?
    @Binding var isPresented: Bool

    // Question
    @State private var qContentType = "latex"
    @State private var latex = ""
    @State private var qImageDatas: [(name: String, nsImage: NSImage)] = []

    // Solution
    @State private var sContentType = "latex"
    @State private var solution = ""
    @State private var sImageDatas: [(name: String, nsImage: NSImage)] = []

    // Meta
    @AppStorage("customCategories") private var customCategoryData: String = ""
    @AppStorage("customCategoryIcons") private var customCategoryIcons: String = ""
    @AppStorage("customCategoryColors") private var customCategoryColors: String = ""
    private var customCategories: [String] {
        get { customCategoryData.isEmpty ? [] : customCategoryData.components(separatedBy: ",") }
        nonmutating set { customCategoryData = newValue.joined(separator: ",") }
    }
    @State private var category = "填空题"
    @State private var showNewCategoryAlert = false
    @State private var newCatName = ""
    @State private var newCatIcon = "tag.fill"
    @State private var newCatColor: Color = .accentColor
    @State private var source = ""
    @State private var note = ""
    @State private var tags: [String] = []
    @State private var tagInput = ""

    // Preview heights
    @State private var qPreviewH: CGFloat = 60
    @State private var sPreviewH: CGFloat = 40

    private var isEditing: Bool { problem != nil }

    private var canSave: Bool {
        let hasQText = !latex.trimmingCharacters(in: .whitespaces).isEmpty
        let hasQImg = !qImageDatas.isEmpty
        let hasSText = !solution.trimmingCharacters(in: .whitespaces).isEmpty
        let hasSImg = !sImageDatas.isEmpty

        let qOk: Bool = switch qContentType {
        case "image": hasQImg
        default: hasQText || hasQImg
        }
        // Solution is optional — if there's any solution content, it's valid
        let sOk: Bool = switch sContentType {
        case "image": hasSImg || !hasSText // no solution, or has images
        default: true // text/latex solution is always valid (can be empty)
        }
        return qOk && sOk
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? locale.editProblem : locale.newProblem).font(.title3.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            Divider()

            // Body
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ScrollView {
                        editorContent.padding(16)
                    }
                    .frame(width: geo.size.width * 0.48)

                    Divider()

                    ScrollView {
                        previewContent.padding(12)
                    }
                    .frame(width: geo.size.width * 0.52)
                    .background(Color.primary.opacity(0.02))
                }
            }

            Divider()
            footerBar
        }
        .frame(minWidth: 920, minHeight: 620)
        .sheet(isPresented: $showNewCategoryAlert) {
            VStack(spacing: 12) {
                Text("添加题型").font(.headline)
                TextField("题型名称", text: $newCatName).textFieldStyle(.roundedBorder).frame(width: 200)
                HStack(spacing: 8) {
                    Text("图标").font(.system(size: 12))
                    TextField("SF Symbol", text: $newCatIcon).textFieldStyle(.roundedBorder).frame(width: 140).font(.system(size: 11))
                    Image(systemName: newCatIcon.isEmpty ? "tag.fill" : newCatIcon).frame(width: 20)
                }
                ColorPicker("颜色", selection: $newCatColor)
                HStack {
                    Button("取消") { showNewCategoryAlert = false }
                    Button("添加") {
                        let t = newCatName.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty, !customCategories.contains(t) {
                            customCategories.append(t)
                            customCategoryIcons = (customCategoryIcons.isEmpty ? "" : customCategoryIcons + ",") + (newCatIcon.isEmpty ? "tag.fill" : newCatIcon)
                            let hex = newCatColor.toHex() ?? "#FF3B30"
                            customCategoryColors = (customCategoryColors.isEmpty ? "" : customCategoryColors + ",") + hex
                            category = t
                        }
                        newCatName = ""; newCatIcon = "tag.fill"; newCatColor = .accentColor
                        showNewCategoryAlert = false
                    }.buttonStyle(.borderedProminent).tint(Accent.red)
                        .disabled(newCatName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 380, height: 220)
        }
        .onAppear {
            if let p = problem {
                qContentType = p.contentType; latex = p.latex
                sContentType = p.solutionContentType; solution = p.solution
                category = p.category; source = p.source; note = p.note
                tags = p.tags; tagInput = ""
                qImageDatas = loadImages(p.imageNames)
                sImageDatas = loadImages(p.solutionImageNames)
            } else { reset() }
        }
    }

    // MARK: - Editor

    private var editorContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ---- QUESTION ----
            sectionHeader(locale.questionLabel)
            contentTypePicker($qContentType)
            contentEditor(for: qContentType, text: $latex, placeholder: "题目内容")
            imageSection($qImageDatas, prompt: qContentType == "image" ? locale.imgPromptQ : locale.imgPromptQAttach)

            Divider().padding(.vertical, 4)

            // ---- SOLUTION ----
            sectionHeader(locale.solutionLabel)
            contentTypePicker($sContentType)
            contentEditor(for: sContentType, text: $solution, placeholder: "解析内容 (可选)")
            imageSection($sImageDatas, prompt: sContentType == "image" ? locale.imgPromptS : locale.imgPromptSAttach)
        }
    }

    @ViewBuilder
    private func contentTypePicker(_ binding: Binding<String>) -> some View {
        Picker("", selection: binding) {
            ForEach(Problem.contentTypes, id: \.self) { ct in
                Text(Problem.contentTypeLabels[Problem.contentTypes.firstIndex(of: ct)!]).tag(ct)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 280)
    }

    @ViewBuilder
    private func contentEditor(for ct: String, text: Binding<String>, placeholder: String) -> some View {
        if ct == "latex" {
            TextEditor(text: text)
                .font(.system(size: 13, design: .monospaced))
                .frame(minHeight: 140)
                .scrollContentBackground(.hidden)
                .padding(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15), lineWidth: 1))
        } else if ct == "text" {
            TextEditor(text: text)
                .font(.system(size: 13))
                .frame(minHeight: 140)
                .scrollContentBackground(.hidden)
                .padding(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15), lineWidth: 1))
        }
        // "image" type: no text editor
    }

    // MARK: - Image Section (shared)

    @ViewBuilder
    private func imageSection(_ datas: Binding<[(name: String, nsImage: NSImage)]>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(prompt).font(.system(size: 11)).foregroundColor(.secondary)

            DropZone { provider in
                if let img = await loadNSImage(from: provider) {
                    let name = save(img)
                    await MainActor.run { datas.wrappedValue.append((name, img)) }
                }
            }
            .frame(height: 60)

            ForEach(Array(datas.wrappedValue.enumerated()), id: \.offset) { idx, item in
                HStack {
                    Image(nsImage: item.nsImage).resizable().scaledToFit().frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text(item.name).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                    Spacer()
                    Button { datas.wrappedValue.remove(at: idx) } label: {
                        Image(systemName: "trash").foregroundColor(.red)
                    }.buttonStyle(.plain)
                }
                .padding(6).background(Color.primary.opacity(0.03)).clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Button { pickImages(into: datas) } label: {
                Label(locale.pickImage, systemImage: "plus").font(.system(size: 12))
            }
        }
    }

    // MARK: - Preview

    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(locale.preview).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
            Divider()

            // Question preview
            sectionLabel("题目")
            if qContentType == "latex" {
                KaTeXWebView(latex: latex, dynamicHeight: $qPreviewH)
                    .frame(height: max(qPreviewH, 30))
            } else if qContentType == "text" {
                PlainTextWebView(text: latex, dynamicHeight: $qPreviewH)
                    .frame(height: max(qPreviewH, 30))
            }
            if !qImageDatas.isEmpty {
                ForEach(Array(qImageDatas.enumerated()), id: \.offset) { _, item in
                    Image(nsImage: item.nsImage).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            if hasSolutionContent {
                Divider()
                sectionLabel("解析")
                if sContentType == "latex" {
                    KaTeXWebView(latex: solution, dynamicHeight: $sPreviewH)
                        .frame(height: max(sPreviewH, 30))
                } else if sContentType == "text" {
                    PlainTextWebView(text: solution, dynamicHeight: $sPreviewH)
                        .frame(height: max(sPreviewH, 30))
                }
                if !sImageDatas.isEmpty {
                    ForEach(Array(sImageDatas.enumerated()), id: \.offset) { _, item in
                        Image(nsImage: item.nsImage).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            if !hasAnyContent {
                Text(locale.previewPlaceholder).font(.system(size: 13)).foregroundColor(.secondary).padding(.top, 40)
            }
        }
    }

    private var hasSolutionContent: Bool {
        !solution.trimmingCharacters(in: .whitespaces).isEmpty || !sImageDatas.isEmpty
    }

    private var hasAnyContent: Bool {
        !latex.trimmingCharacters(in: .whitespaces).isEmpty || !qImageDatas.isEmpty || hasSolutionContent
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text).font(.system(size: 13, weight: .semibold))
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Picker(locale.categoryLabel, selection: $category) {
                ForEach(locale.categories, id: \.self) { c in Text(c).tag(c) }
                ForEach(customCategories, id: \.self) { c in Text(c).tag(c) }
                Divider()
                Text("添加题型…").tag("__new__")
            }.frame(width: 120)
            .onChange(of: category) { _, newVal in
                if newVal == "__new__" {
                    category = "填空题" // reset
                    newCatName = ""
                    showNewCategoryAlert = true
                }
            }

            TextField(locale.source, text: $source).frame(width: 110).textFieldStyle(.roundedBorder)
            if source.isEmpty, let last = UserDefaults.standard.string(forKey: "lastSource"), !last.isEmpty {
                Button { source = last } label: {
                    Text("\(last) ↲").font(.system(size: 9)).foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
            TextField(locale.note, text: $note).frame(width: 90).textFieldStyle(.roundedBorder)
            TextField(locale.tagPlaceholder, text: $tagInput).frame(width: 120).textFieldStyle(.roundedBorder)
                .onSubmit { let t = tagInput.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty, !tags.contains(t) { tags.append(t) }; tagInput = "" }

            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 2) {
                                Text(tag).font(.system(size: 11))
                                Button { tags.removeAll { $0 == tag } } label: {
                                    Image(systemName: "xmark").font(.system(size: 7, weight: .bold))
                                }.buttonStyle(.plain)
                            }.padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.primary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }.frame(width: 120)
            }

            Spacer()
            Button(locale.cancel) { isPresented = false }.buttonStyle(.bordered)
            Button(isEditing ? locale.saveEdit : locale.addProblem) { save() }
                .buttonStyle(.borderedProminent).tint(Accent.red).disabled(!canSave)
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
    }

    // MARK: - Image helpers

    private func loadImages(_ names: [String]) -> [(String, NSImage)] {
        names.compactMap { name in
            store.loadImage(named: name).flatMap { NSImage(data: $0) }.map { (name, $0) }
        }
    }

    private func pickImages(into binding: Binding<[(name: String, nsImage: NSImage)]>) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let img = NSImage(contentsOf: url) {
                let name = save(img)
                binding.wrappedValue.append((name, img))
            }
        }
    }

    private func loadNSImage(from provider: NSItemProvider) async -> NSImage? {
        for id in [UTType.png.identifier, UTType.jpeg.identifier, UTType.heic.identifier]
            where provider.hasItemConformingToTypeIdentifier(id) {
            if let img = await loadImg(id, from: provider) { return img }
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            if let path = await loadStr(UTType.fileURL.identifier, from: provider),
               let url = URL(string: path), let img = NSImage(contentsOf: url) { return img }
        }
        return await loadImg(UTType.image.identifier, from: provider)
    }

    private func loadImg(_ tid: String, from p: NSItemProvider) async -> NSImage? {
        await withCheckedContinuation { c in
            p.loadDataRepresentation(forTypeIdentifier: tid) { d, _ in
                c.resume(returning: d.flatMap(NSImage.init(data:)))
            }
        }
    }

    private func loadStr(_ tid: String, from p: NSItemProvider) async -> String? {
        await withCheckedContinuation { c in
            p.loadDataRepresentation(forTypeIdentifier: tid) { d, _ in
                c.resume(returning: d.flatMap { String(data: $0, encoding: .utf8) })
            }
        }
    }

    private func save(_ img: NSImage) -> String {
        let name = "\(UUID().uuidString).png"
        if let tiff = img.tiffRepresentation,
           let bmp = NSBitmapImageRep(data: tiff),
           let png = bmp.representation(using: .png, properties: [:]) {
            _ = store.saveImage(data: png, filename: name)
        }
        return name
    }

    // MARK: - Save

    private func reset() {
        qContentType = "latex"; latex = ""; qImageDatas = []
        sContentType = "latex"; solution = ""; sImageDatas = []
        category = "填空题"; source = ""; note = ""
        tags = []; tagInput = ""
    }

    private func save() {
        guard canSave else { return }
        let qNames = qImageDatas.map(\.name)
        let sNames = sImageDatas.map(\.name)

        if let existing = problem {
            // Remove stale images
            for name in existing.imageNames where !qNames.contains(name) {
                try? FileManager.default.removeItem(at: store.imageDirectory.appendingPathComponent(name))
            }
            for name in existing.solutionImageNames where !sNames.contains(name) {
                try? FileManager.default.removeItem(at: store.imageDirectory.appendingPathComponent(name))
            }
            // Save new images
            for item in qImageDatas where !existing.imageNames.contains(item.name) { _ = save(item.nsImage) }
            for item in sImageDatas where !existing.solutionImageNames.contains(item.name) { _ = save(item.nsImage) }

            var u = existing
            u.contentType = qContentType; u.latex = latex
            u.solutionContentType = sContentType; u.solution = solution
            u.category = category; u.source = source; u.note = note
            u.tags = tags; u.imageNames = qNames; u.solutionImageNames = sNames
            store.update(u)
        } else {
            for item in qImageDatas + sImageDatas { _ = save(item.nsImage) }
            store.create(
                contentType: qContentType, latex: latex, tags: tags,
                category: category, source: source, note: note,
                solution: solution, solutionContentType: sContentType,
                solutionImageNames: sNames, imageNames: qNames
            )
        }
        if !source.trimmingCharacters(in: .whitespaces).isEmpty {
            UserDefaults.standard.set(source, forKey: "lastSource")
        }
        isPresented = false
    }
}

// MARK: - Reusable Drop Zone

struct DropZone: View {
    @Environment(LocaleManager.self) private var locale
    @State private var isTargeted = false
    let onDrop: @Sendable (NSItemProvider) async -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .foregroundColor(isTargeted ? Accent.red : Color.primary.opacity(0.18))
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(isTargeted ? Accent.red.opacity(0.05) : Color.primary.opacity(0.015)))
            .overlay {
                VStack(spacing: 3) {
                    Image(systemName: isTargeted ? "doc.fill" : "photo.on.rectangle")
                        .font(.system(size: 18)).foregroundColor(isTargeted ? Accent.red : .secondary)
                    Text(isTargeted ? locale.releaseToAdd : locale.dropZoneHint)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            .onDrop(of: [.image, .fileURL], isTargeted: $isTargeted) { providers in
                Task { for p in providers { await onDrop(p) } }
                return true
            }
    }
}

extension Color {
    func toHex() -> String? {
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int(nsColor.redComponent * 255)
        let g = Int(nsColor.greenComponent * 255)
        let b = Int(nsColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
