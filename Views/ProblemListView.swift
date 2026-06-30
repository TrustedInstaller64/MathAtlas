import SwiftUI

struct ProblemListView: View {
    @Environment(ProblemStore.self) private var store
    @Environment(LocaleManager.self) private var locale
    @Binding var query: String
    let activeCategory: String
    let activeTags: Set<String>
    let activeSource: String?
    @Binding var solutionFilter: SolutionFilter
    @Binding var selecting: Bool
    @Binding var selectedIDs: Set<String>
    let printQueue: PrintQueueManager
    let onEdit: (Problem) -> Void
    let onOpen: (Problem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary).font(.system(size: 13))
                TextField(locale.searchPlaceholder, text: $query).textFieldStyle(.plain).font(.system(size: 13))
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(10).background(Accent.bgSecondary).clipShape(RoundedRectangle(cornerRadius: 8)).padding(16)

            // Solution filter
            Picker("", selection: $solutionFilter) {
                ForEach(SolutionFilter.allCases, id: \.self) { f in
                    Text(f.label(locale)).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            if !store.ready {
                Spacer(); ProgressView(locale.loading); Spacer()
            } else if filtered.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: store.problems.isEmpty ? "tray" : "magnifyingglass")
                        .font(.system(size: 36)).foregroundColor(.secondary.opacity(0.5))
                    Text(store.problems.isEmpty ? locale.emptyLibrary : locale.noMatch)
                        .font(.system(size: 13)).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 80)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, problem in
                            ProblemCardView(problem: problem, index: idx + 1,
                                           selecting: $selecting, selectedIDs: $selectedIDs,
                                           printQueue: printQueue, activeLevel: store.level,
                                           onEdit: onEdit, onOpen: onOpen)
                        }
                    }.padding(16)
                }
            }
        }
        .background(Color.clear)
    }

    private var filtered: [Problem] {
        store.filtered(query: query, category: activeCategory, tags: Array(activeTags), source: activeSource)
            .filter { p in
                switch solutionFilter {
                case .all:  return true
                case .has:  return !p.solution.trimmingCharacters(in: .whitespaces).isEmpty
                                || !p.solutionImageNames.isEmpty
                case .none: return p.solution.trimmingCharacters(in: .whitespaces).isEmpty
                                && p.solutionImageNames.isEmpty
                }
            }
    }
}
