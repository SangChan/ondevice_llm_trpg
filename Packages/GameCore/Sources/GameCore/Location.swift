/// 장소. `connections`은 이동 가능한 인접 장소의 집합이다 (원본 설계 §4).
public struct Location: Codable, Sendable, Equatable {
    public let id: EntityID
    public let name: String
    public var connections: Set<EntityID>

    public init(id: EntityID, name: String, connections: Set<EntityID> = []) {
        self.id = id
        self.name = name
        self.connections = connections
    }
}
