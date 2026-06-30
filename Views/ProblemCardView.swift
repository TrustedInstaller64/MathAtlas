import SwiftUI

struct ProblemCardView: View {
    @Environment(ProblemStore.self) private var store
    @Environment(LocaleManager.self) private var locale
    let problem: Problem
    let index: Int
    @Binding var selecting: Bool
    @Binding var selectedIDs: Set<String>
    let printQueue: PrintQueueManager
    let activeLevel: AppLevel
    let onEdit: (Problem) -> Void
    let onOpen: (Problem) -> Void

    @State private var showDeleteAlert = false
    @State private var showSource = false
    @State private var isHovering = false

    private let categoryColors: [String: Color] = [
        "填空题": .orange, "选择题": .blue, "解答题": .green,
        "未分类": Accent.textSecondary,
    ]

    var body: some View {
        Button(action: { onOpen(problem) }) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                    .padding(.horizontal, 16).padding(.vertical, 10)
                Divider()

                // Question preview — plain text, no WebView
                Text(store.plainTextPreview(for: problem))
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .lineLimit(3)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 10)

                // Images thumbnail
                if !problem.imageNames.isEmpty {
                    imagesRow
                    if problem.contentType != "image" || !problem.latex.trimmingCharacters(in: .whitespaces).isEmpty {
                        Divider()
                    }
                }

                // Tags
                if !problem.tags.isEmpty {
                    Divider()
                    tagsRow.padding(.horizontal, 16).padding(.vertical, 10)
                }
            }
            .background(Accent.bgPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isHovering ? Accent.red.opacity(0.4) : Accent.border, lineWidth: 1)
            )
            .shadow(color: isHovering ? Color.black.opacity(0.06) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovering = h } }
        .alert(locale.deleteTitle, isPresented: $showDeleteAlert) {
            Button(locale.cancel, role: .cancel) {}
            Button(locale.deleteConfirm, role: .destructive) { store.delete(problem) }
        } message: { Text(locale.deleteMessage) }
        .sheet(isPresented: $showSource) { sourceViewer }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 8) {
            if selecting {
                Button {
                    if selectedIDs.contains(problem.id) { selectedIDs.remove(problem.id) }
                    else { selectedIDs.insert(problem.id) }
                } label: {
                    Image(systemName: selectedIDs.contains(problem.id) ? "checkmark.square.fill" : "square")
                        .font(.system(size: 15)).foregroundColor(selectedIDs.contains(problem.id) ? Accent.red : .secondary)
                }.buttonStyle(.plain)
            }

            Text("\(index)")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                .frame(width: 24, height: 24).background(Accent.red)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(problem.category)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background((categoryColors[problem.category] ?? Accent.textSecondary).opacity(0.18))
                .foregroundColor(categoryColors[problem.category] ?? Accent.textSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            if !problem.source.isEmpty {
                Text(problem.source).font(.system(size: 11)).foregroundColor(.secondary)
            }
            if !problem.note.isEmpty {
                Text("· \(problem.note)").font(.system(size: 11)).foregroundColor(.secondary)
            }
            if !problem.solution.trimmingCharacters(in: .whitespaces).isEmpty || !problem.solutionImageNames.isEmpty {
                Text(locale.localeStr("有解析", "Sol.")).font(.system(size: 9)).foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 3))
            }
            Spacer()
            // Edit button — always visible (match SPM reference)
            actionBtn("square.and.pencil", "编辑") { onEdit(problem) }
            if isHovering {
                HStack(spacing: 2) {
                    let inQueue = printQueue.contains(problemID: problem.id)
                    actionBtn(inQueue ? "printer.fill" : "printer", "待打印") {
                        printQueue.toggle(problemID: problem.id, level: activeLevel)
                    }
                    actionBtn("chevron.left.forwardslash.chevron.right", "查看源码") { showSource = true }
                    actionBtn("trash", "删除", destructive: true) { showDeleteAlert = true }
                }
            }
        }
    }

    // MARK: - Images

    private var imagesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(problem.imageNames, id: \.self) { name in
                    cachedImage(name)
                        .resizable().scaledToFit().frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
    }

    private func cachedImage(_ name: String) -> Image {
        if let data = store.loadImage(named: name),
           let nsImg = NSImage(data: data) {
            return Image(nsImage: nsImg)
        }
        return Image(systemName: "photo")
    }

    // MARK: - Tags

    private var tagsRow: some View {
        HStack(spacing: 6) {
            ForEach(problem.tags, id: \.self) { tag in
                Text(tag).font(.system(size: 11))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .foregroundColor(.secondary)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    // MARK: - Source viewer

    private var sourceViewer: some View {
        VStack(spacing: 0) {
            HStack {
                Text(locale.sourceTitle).font(.headline)
                Spacer()
                Button(locale.close) { showSource = false }.buttonStyle(.bordered)
            }.padding()
            Divider()
            ScrollView {
                Text(problem.latex)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(width: 600, height: 400)
    }

    private func actionBtn(_ icon: String, _ label: String, destructive: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 12)).frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundColor(destructive ? Accent.red : Accent.textSecondary.opacity(0.6))
        .help(label)
    }
}
