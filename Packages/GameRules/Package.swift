// swift-tools-version: 6.2
import PackageDescription

// GameRules: 자연어 대상 해석(ActionResolver), 행동 칩 파생 등
// GameCore 위에 얹히는 규칙 계층. FoundationModels는 여전히 모른다 (설계 §37).
// Phase 2(§40)에서 채워진다 — 지금은 모듈 경계만 확보한다.
let package = Package(
    name: "GameRules",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "GameRules", targets: ["GameRules"])
    ],
    dependencies: [
        .package(path: "../GameCore")
    ],
    targets: [
        .target(
            name: "GameRules",
            dependencies: ["GameCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "GameRulesTests",
            dependencies: ["GameRules"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
