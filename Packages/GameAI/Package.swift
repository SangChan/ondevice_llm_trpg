// swift-tools-version: 6.2
import PackageDescription

// GameAI: IntentParsing / Narrating 프로토콜 + 그 구현체(LLM 없는 Classic Mode용
// KeywordIntentParser/TemplateNarrator/ScenarioNarrator 포함, Phase 3의
// FoundationModels 구현체도 여기 들어온다). GameCore·GameRules에 의존하지만
// 거꾸로는 아무도 이 모듈을 모른다 (설계 §29, §37).
let package = Package(
    name: "GameAI",
    // macOS(.v15)로는 `import FoundationModels`가 이 SDK에서 존재하지 않는다 — 실제로
    // 빌드해서 확인한 최소값이 macOS 26이다(Phase 3 도입 시점에 검증).
    platforms: [.iOS(.v26), .macOS(.v26)],
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
