// swift-tools-version: 6.2
import PackageDescription

// GameAI: IntentParsing / Narrating 프로토콜과 FoundationModels 구현체.
// GameCore에 의존하지만 GameCore는 이 모듈을 모른다 (설계 §29, §37).
// Phase 3(§40)에서 채워진다 — 지금은 모듈 경계만 확보한다.
let package = Package(
    name: "GameAI",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "GameAI", targets: ["GameAI"])
    ],
    dependencies: [
        .package(path: "../GameCore")
    ],
    targets: [
        .target(
            name: "GameAI",
            dependencies: ["GameCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "GameAITests",
            dependencies: ["GameAI"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
