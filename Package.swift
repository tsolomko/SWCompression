// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "SWCompression",
    products: [
        .library(
            name: "SWCompression",
            targets: ["SWCompression"]),
    ],
    targets: [
        .target(
            name: "SWCompression",
            path: "Sources",
            sources: ["Common", "7-Zip", "BZip2", "Deflate", "GZip", "LZMA", "TAR", "XZ", "ZIP", "Zlib"])
    ],
    swiftLanguageVersions: [4]
)
