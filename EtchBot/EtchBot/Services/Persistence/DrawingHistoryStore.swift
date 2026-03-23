// DrawingHistoryStore.swift — EtchBot
// Optional: saves metadata about past drawing sessions (not the full image,
// just settings and timestamps) for history display.

import Foundation

/// Metadata for a completed drawing session.
public struct DrawingRecord: Identifiable, Codable, Sendable {
    public let id: UUID
    public let date: Date
    public let pointCount: Int
    public let estimatedMinutes: Int
    public let deviceName: String
    public let thumbnailData: Data?  // small JPEG of the preview

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        pointCount: Int,
        estimatedMinutes: Int,
        deviceName: String,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.date = date
        self.pointCount = pointCount
        self.estimatedMinutes = estimatedMinutes
        self.deviceName = deviceName
        self.thumbnailData = thumbnailData
    }
}

public final class DrawingHistoryStore: Sendable {

    private let fileURL: URL
    private let maxRecords = 50

    public init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = docs.appendingPathComponent("etchbot_history.json")
    }

    public func loadAll() -> [DrawingRecord] {
        guard let data = try? Data(contentsOf: fileURL),
              let records = try? JSONDecoder().decode([DrawingRecord].self, from: data) else {
            return []
        }
        return records.sorted { $0.date > $1.date }
    }

    public func add(_ record: DrawingRecord) {
        var records = loadAll()
        records.insert(record, at: 0)
        if records.count > maxRecords { records = Array(records.prefix(maxRecords)) }
        persist(records)
    }

    public func delete(id: UUID) {
        var records = loadAll()
        records.removeAll { $0.id == id }
        persist(records)
    }

    public func clearAll() {
        persist([])
    }

    private func persist(_ records: [DrawingRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
