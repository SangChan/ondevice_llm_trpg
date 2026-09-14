// swift-tools-version: 6.2
import PackageDescription

// GameAI: IntentParsing / Narrating 프로토콜 + 그 구현체(LLM 없는 Classic Mode용
// KeywordIntentParser/TemplateNarrator/ScenarioNarrator 포함, Phase 3의
// FoundationModels 구현체도 여기 들어온다). GameCore·GameRules에 의존하지만
// 거꾸로는 아무도 이 모듈을 모른다 (설계 §29, §37).
let package = Package(
    name: "GameAI",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "GameAI", targets: ["GameAI"])
    ],
    dependencies: [
        .package(path: "../GameCore"),
        .package(path: "../GameRules")
    ],
    targets: [
        .target(
            name: "GameAI",
            dependencies: ["GameCore", "GameRules"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "GameAITests",
            dependencies: ["GameAI"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
