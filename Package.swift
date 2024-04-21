// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "SWCompression",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v11),
        .tvOS(.v11),
        .watchOS(.v4),
        // TODO: Enable after upgrading to Swift 5.9.
        // .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SWCompression",
            targets: ["SWCompression"]),
    ],
    dependencies: [
        .package(name: "BitByteData", url: "https://github.com/tsolomko/BitByteData",
                 from: "2.0.0"),
        .package(name: "SwiftCLI", url: "https://github.com/jakeheis/SwiftCLI",
                 from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "SWCompression",
            dependencies: ["BitByteData"],
            path: "Sources",
            exclude: ["swcomp"],
            sources: ["Common", "7-Zip", "BZip2", "Deflate", "GZip", "LZ4", "LZMA", "LZMA2", "TAR", "XZ", "ZIP", "Zlib"],
            resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(
            name: "swcomp",
            dependencies: ["SWCompression", "SwiftCLI"],
            path: "Sources",
            exclude: ["Common", "7-Zip", "BZip2", "Deflate", "GZip", "LZ4", "LZMA", "LZMA2", "TAR", "XZ", "ZIP", "Zlib", "PrivacyInfo.xcprivacy"],
            sources: ["swcomp"]),
    ],
    swiftLanguageVersions: [.v5]
)
