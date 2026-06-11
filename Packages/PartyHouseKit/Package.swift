// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PartyHouseKit",
    defaultLocalization: "en",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
    products: [
        .library(name: "PartyCore", targets: ["PartyCore"]),
        .library(name: "PartyHue", targets: ["PartyHue"]),
        .library(name: "PartyHomeAssistant", targets: ["PartyHomeAssistant"]),
        .library(name: "PartyLIFX", targets: ["PartyLIFX"]),
        .library(name: "PartyUI", targets: ["PartyUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/home-assistant/HAKit.git", from: "0.4.0"),
    ],
    targets: [
        .target(name: "PartyCore"),
        .target(name: "PartyHue", dependencies: ["PartyCore"]),
        .target(
            name: "PartyHomeAssistant",
            dependencies: [
                "PartyCore",
                .product(name: "HAKit", package: "HAKit"),
            ]
        ),
        .target(name: "PartyLIFX", dependencies: ["PartyCore"]),
        .target(name: "PartyUI", dependencies: ["PartyCore", "PartyHue"]),
        .testTarget(
            name: "PartyCoreTests",
            dependencies: ["PartyCore", "PartyHue", "PartyLIFX"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
