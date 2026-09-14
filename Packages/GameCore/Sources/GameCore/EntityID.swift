import Foundation

/// LLM에게 내부 UUID를 노출하지 않기 위한 불투명 식별자 (원본 설계 §4).
public struct EntityID: Hashable, Codable, Sendable {
    public let rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

extension EntityID: CustomStringConvertible {
    public var description: String { rawValue.uuidString }
}
