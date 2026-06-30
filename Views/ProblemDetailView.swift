import SwiftUI
import AppKit

struct ProblemDetailView: View {
    @Environment(ProblemStore.self) private var store
    @Environment(LocaleManager.self) private var locale

    let index: Int
    let onDismiss: () -> Void
    @State private var problem: Problem
    @State private var dynamicHeightA: CGFloat = 60
    @State private var dynamicHeightB: CGFloat = 60
    @State private var solutionBlurred = true
    @State private var showDeleteAlert = false
    @State private var showEditor = false
    @State private var showSource = false
    @Environment(PrintQueueManager.self) private var printQueue

    init(problem: Problem, index: Int, onDismiss: @escaping () -> Void) {
        self.index = index; self.onDismiss = onDismiss
        self._problem = State(initialValue: problem)
    }

    private let categoryColors: [String: Color] = [
        "填空题": .orange, "选择题": .blue, "解答题": .green,
        "未分类": Accent.textSecondary,
    ]

    var body: some View {
        detailContent
            .frame(minWidth: 700, minHeight: 500)
    }

    private var detailContent: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Text("#\(index)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Accent.red)
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

                Spacer()

                // Print queue
                let inQueue = printQueue.contains(problemID: problem.id)
                Button {
                    printQueue.toggle(problemID: problem.id, level: store.level)
                } label: {
                    Image(systemName: inQueue ? "printer.fill" : "printer").font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("待打印")

                // View LaTeX source
                Button { showSource = true } label: {
                    Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("查看源码")

                // Edit
                Button { showEditor = true } label: {
                    Image(systemName: "square.and.pencil").font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("编辑")

                // Delete
                Button { showDeleteAlert = true } label: {
                    Image(systemName: "trash").font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .help(locale.deleteConfirm)
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(.bar)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Question body
                    questionContent
                        .padding(20)

                    Divider().padding(.horizontal, 20)

                    // Images
                    if !problem.imageNames.isEmpty {
                        imagesSection
                            .padding(20)
                        Divider().padding(.horizontal, 20)
                    }

                    // Solution — blurred
                    if hasSolutionContent {
                        solutionSection
                            .padding(20)
                    }

                    // Tags
                    if !problem.tags.isEmpty {
                        Divider().padding(.horizontal, 20)
                        HStack(spacing: 6) {
                            ForEach(problem.tags, id: \.self) { tag in
                                Text(tag).font(.system(size: 11))
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .foregroundColor(.secondary)
                                    .background(Color.primary.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .background(GlassEffectView().ignoresSafeArea())
        .onDisappear {
            dynamicHeightA = 0; dynamicHeightB = 0
        }
        .alert(locale.deleteTitle, isPresented: $showDeleteAlert) {
            Button(locale.cancel, role: .cancel) {}
            Button(locale.deleteConfirm, role: .destructive) {
                store.delete(problem); onDismiss()
            }
        } message: { Text(locale.deleteMessage) }
        .sheet(isPresented: $showEditor, onDismiss: {
            // Refresh problem from store after edit
            if let updated = store.problems.first(where: { $0.id == problem.id }) {
                problem = updated
            }
        }) {
            ProblemEditorView(problem: problem, isPresented: $showEditor)
                .environment(store).environment(locale)
        }
        .sheet(isPresented: $showSource) {
            VStack(spacing: 0) {
                HStack {
                    Text("LaTeX 源码").font(.headline)
                    Spacer()
                    Button("关闭") { showSource = false }.buttonStyle(.bordered)
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
    }

    // MARK: - Question

    @ViewBuilder
    private var questionContent: some View {
        if problem.contentType == "latex" {
            KaTeXWebView(latex: problem.latex, dynamicHeight: $dynamicHeightA)
                .frame(minHeight: max(dynamicHeightA, 40))
        } else if problem.contentType == "text" {
            PlainTextWebView(text: problem.latex, dynamicHeight: $dynamicHeightA)
                .frame(minHeight: max(dynamicHeightA, 40))
        }
        // image type → just shows images below
    }

    // MARK: - Images

    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(problem.imageNames, id: \.self) { name in
                if let data = store.loadImage(named: name),
                   let nsImg = NSImage(data: data) {
                    Image(nsImage: nsImg)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Solution (blurred)

    private var hasSolutionContent: Bool {
        !problem.solution.trimmingCharacters(in: .whitespaces).isEmpty
        || !problem.solutionImageNames.isEmpty
    }

    private var solutionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(locale.solutionToggle)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if !solutionBlurred {
                    Button(locale.localeStr("隐藏", "Hide")) {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            solutionBlurred = true
                        }
                    }
                    .font(.system(size: 12))
                    .buttonStyle(.bordered)
                }
            }

            ZStack {
                // Solution content
                VStack(alignment: .leading, spacing: 10) {
                    if problem.solutionContentType == "latex" {
                        KaTeXWebView(latex: problem.solution, dynamicHeight: $dynamicHeightB)
                            .frame(minHeight: max(dynamicHeightB, 60))
                    } else if problem.solutionContentType == "text" {
                        PlainTextWebView(text: problem.solution, dynamicHeight: $dynamicHeightB)
                            .frame(minHeight: max(dynamicHeightB, 60))
                    }

                    ForEach(problem.solutionImageNames, id: \.self) { name in
                        if let data = store.loadImage(named: name),
                           let nsImg = NSImage(data: data) {
                            Image(nsImage: nsImg)
                                .resizable().scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .blur(radius: solutionBlurred ? 20 : 0)
                .opacity(solutionBlurred ? 0.5 : 1)
                .animation(.easeInOut(duration: 0.5), value: solutionBlurred)
                .allowsHitTesting(!solutionBlurred)

                // Tap to reveal overlay
                if solutionBlurred {
                    VStack(spacing: 10) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text(locale.localeStr("点击查看解析", "Tap to reveal solution"))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            solutionBlurred = false
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

