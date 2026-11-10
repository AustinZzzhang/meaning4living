import Foundation

public enum StateError: LocalizedError {
    case unsupportedVersion
    case invalidSettings
    case invalidRecord

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return "数据版本不兼容，原文件已保留。"
        case .invalidSettings: return "保存的设置无效，原文件已保留。"
        case .invalidRecord: return "保存的计时数据无效，原文件已保留。"
        }
    }
}

public struct StateRepository {
    public let url: URL

    /// Creates storage at url without accessing its file; returns a repository.
    public init(url: URL) {
        self.url = url
    }

    /// Loads and validates the configured file; takes no parameters and returns defaults only if it is missing.
    public func load() throws -> SavedState {
        guard FileManager.default.fileExists(atPath: url.path) else { return SavedState() }
        let state = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: url))
        try validate(state)
        return state
    }

    /// Checks state with the same rules for reading and writing; returns nothing and throws for invalid data.
    private func validate(_ state: SavedState) throws {
        guard (1...2).contains(state.version) else { throw StateError.unsupportedVersion }
        guard state.settings.validationMessage == nil else { throw StateError.invalidSettings }
        for (key, record) in state.records {
            guard record.isValid(for: key) else { throw StateError.invalidRecord }
        }
    }

    /// Validates state before atomically writing the configured file; returns nothing, preserves old bytes on error.
    public func save(_ state: SavedState) throws {
        try validate(state)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: url, options: [.atomic])
    }
}
