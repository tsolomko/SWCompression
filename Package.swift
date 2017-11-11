// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "SWCompression",
    products: [
        .library(
            name: "SWCompression",
            targets: ["SWCompression"])
    ],
    // SWCOMP: Uncomment the lines below to build swcomp example program.
    // dependencies: [
    //     .package(url: "https://github.com/jakeheis/SwiftCLI", from: "4.0.0")
    // ],
    targets: [
        // SWCOMP: Uncomment the lines below to build swcomp example program.
        // .target(
        //     name: "swcomp",
        //     dependencies: ["SWCompression", "SwiftCLI"],
        //     path: "Sources",
        //     sources: ["swcomp"]),
        .target(
            name: "SWCompression",
            path: "Sources",
            sources: ["Common", "7-Zip", "BZip2", "Deflate", "GZip", "LZMA", "LZMA2", "TAR", "XZ", "ZIP", "Zlib"])
    ],
    swiftLanguageVersions: [4]
)
