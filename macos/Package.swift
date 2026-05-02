// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Livepal",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "Livepal", targets: ["Livepal"]),
    ],
    targets: [
        .executableTarget(
            name: "Livepal",
            path: "Sources/Livepal"
        ),
    ]
)
