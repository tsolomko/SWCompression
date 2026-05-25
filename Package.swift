// swift-tools-version:6.0
import PackageDescription

var package = Package(
    name: "SWCompression",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "SWCompression",
            targets: ["SWCompression"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tsolomko/BitByteData", from: "2.1.0"),
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
    swiftLanguageModes: [.v5]
)

#if os(macOS)
package.dependencies.append(.package(url: "https://github.com/jakeheis/SwiftCLI", from: "6.0.0"))
package.targets.append(.executableTarget(name: "swcomp", dependencies: ["SWCompression", "SwiftCLI"], path: "Sources",
            exclude: ["Common", "7-Zip", "BZip2", "Deflate", "GZip", "LZ4", "LZMA", "LZMA2", "TAR", "XZ", "ZIP", "Zlib", "PrivacyInfo.xcprivacy"],
            sources: ["swcomp"]))
#endif
