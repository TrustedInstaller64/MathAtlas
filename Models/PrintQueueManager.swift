import SwiftUI

struct PrintQueueEntry: Codable, Identifiable, Equatable {
    var id: String { problemID }
    let problemID: String
    let level: String // "high" or "middle"
}

@Observable
final class PrintQueueManager {
    private(set) var entries: [PrintQueueEntry] = []

    private let storageKey = "printQueue:v1"

    init() { load() }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([PrintQueueEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    // MARK: - Operations

    var count: Int { entries.count }

    func contains(problemID: String) -> Bool {
        entries.contains { $0.problemID == problemID }
    }

    func add(problemID: String, level: AppLevel) {
        guard !contains(problemID: problemID) else { return }
        entries.append(PrintQueueEntry(problemID: problemID, level: level.id))
        save()
    }

    func remove(problemID: String) {
        entries.removeAll { $0.problemID == problemID }
        save()
    }

    func toggle(problemID: String, level: AppLevel) {
        if contains(problemID: problemID) { remove(problemID: problemID) }
        else { add(problemID: problemID, level: level) }
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        entries.move(fromOffsets: fromOffsets, toOffset: toOffset)
        save()
    }

    func clearAll() {
        entries.removeAll()
        save()
    }

    func replaceAll(_ newEntries: [PrintQueueEntry]) {
        entries = newEntries
        save()
    }

    func addBlank(problemID: String) {
        entries.append(PrintQueueEntry(problemID: problemID, level: "__blank__"))
        save()
    }
}
