// swift-tools-version:5.5
import PackageDescription

var package = Package(
    name: "SWCompression",
    platforms: [
        .macOS(.v11),
        .iOS(.v14),
        .tvOS(.v14),
        .watchOS(.v7),
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
    ],
    targets: [
        .target(
            name: "SWCompression",
            dependencies: ["BitByteData"],
            path: "Sources",
            exclude: ["swcomp"],
            sources: ["Common", "7-Zip", "BZip2", "Deflate", "GZip", "LZ4", "LZMA", "LZMA2", "TAR", "XZ", "ZIP", "Zlib"],
            resources: [.copy("PrivacyInfo.xcprivacy")]),
    ],
    swiftLanguageVersions: [.v5]
)

#if os(macOS)
package.dependencies.append(.package(name: "SwiftCLI", url: "https://github.com/jakeheis/SwiftCLI", from: "6.0.0"))
package.targets.append(.executableTarget(name: "swcomp", dependencies: ["SWCompression", "SwiftCLI"], path: "Sources",
            exclude: ["Common", "7-Zip", "BZip2", "Deflate", "GZip", "LZ4", "LZMA", "LZMA2", "TAR", "XZ", "ZIP", "Zlib", "PrivacyInfo.xcprivacy"],
            sources: ["swcomp"]))
#endif
