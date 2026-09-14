// swift-tools-version: 6.2
import PackageDescription

// GameCore: 게임 규칙과 상태의 단일 소스.
// Foundation 외부 의존성 없음 — AI/UI 계층을 몰라야 한다 (설계 §3, §37).
let package = Package(
    name: "GameCore",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "GameCore", targets: ["GameCore"])
    ],
    targets: [
        .target(
            name: "GameCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "GameCoreTests",
            dependencies: ["GameCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
