// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LiveChatAE",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)   // only so that `swift test` runs the platform-independent tests on a Mac
    ],
    products: [
        .library(name: "LiveChatAE", targets: ["LiveChatAE"])
    ],
    targets: [
        .target(name: "LiveChatAE", path: "Sources/LiveChatAE"),
        .testTarget(name: "LiveChatAETests", dependencies: ["LiveChatAE"], path: "Tests/LiveChatAETests")
    ]
)
