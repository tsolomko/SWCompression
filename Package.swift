import PackageDescription

let package = Package(
    name: "SWCompression",
    swiftLanguageVersions: [3],
    exclude: [
      "Sources/Service/",
      "Tests/"
    ]
)
