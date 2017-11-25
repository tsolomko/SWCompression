# SWCompression

[![Swift 4](https://img.shields.io/badge/Swift-4.0-blue.svg)](https://developer.apple.com/swift/)
[![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/tsolomko/SWCompression/master/LICENSE)
[![Build Status](https://travis-ci.org/tsolomko/SWCompression.svg?branch=develop)](https://travis-ci.org/tsolomko/SWCompression)

A framework with (de)compression algorithms and functions for processing various archives and containers.

## What is this?

SWCompression &mdash; is a framework with a collection of functions for:

1. Decompression (and sometimes compression) using different algorithms.
2. Reading (and sometimes writing) archives of different formats.
3. Reading containers such as ZIP, TAR and 7-Zip.

It also works both on Apple platforms and __Linux__.

All features are listed in the tables below.
"TBD" means that feature is planned but not implemented (yet).

|               | Deflate | BZip2 | LZMA/LZMA2 |
| ------------- | ------- | ----- | ---------- |
| Decompression | ✅      | ✅     | ✅         |
| Compression   | ✅      | ✅     | TBD        |

|       | Zlib | GZip | XZ  |
| ----- | ---- | ---- | --- |
| Read  | ✅   | ✅    | ✅  |
| Write | ✅   | ✅    | TBD |

|       | ZIP | TAR | 7-Zip |
| ----- | --- | --- | ----- |
| Read  | ✅  | ✅   | ✅    |
| Write | TBD | TBD | TBD   |

Also, SWCompression is _written with Swift only._

## Installation

SWCompression can be integrated into your project using Swift Package Manager, CocoaPods or Carthage.

### Swift Package Manager

Add SWCompression to you package dependencies and also specify it as a dependency for your target, e.g.:

```swift
import PackageDescription

let package = Package(
    name: "PackageName",
    dependencies: [
        .package(url: "https://github.com/tsolomko/SWCompression.git",
                 from: "4.0.0")
    ],
    targets: [
        .target(
            name: "TargetName",
            dependencies: ["SWCompression"]
        )
    ]
)
```

More details you can find in [Swift Package Manager's Documentation](https://github.com/apple/swift-package-manager/tree/master/Documentation).

### CocoaPods

Add to your Podfile `pod 'SWCompression'`.

If you need only some parts of framework, you can install only them using sub-podspecs.
Available subspecs:

- SWCompression/BZip2
- SWCompression/Deflate
- SWCompression/Gzip
- SWCompression/LZMA
- SWCompression/LZMA2
- SWCompression/SevenZip
- SWCompression/TAR
- SWCompression/XZ
- SWCompression/Zlib
- SWCompression/ZIP

Also, do not forget to include `use_frameworks!` line in your Podfile.

To complete installation, run `pod install`.

#### "Optional Dependencies"

Both ZIP and 7-Zip containers have a single compression method which is most likely to be used,
for compression of data inside them. This is Deflate for ZIP and LZMA/LZMA2 for 7-Zip.
Thus, SWCompression/ZIP subspec have SWCompression/Deflate subspec as a dependency
and SWCompression/LZMA subspec as a dependency for SWCompression/SevenZip.

But both of these formats support other compression methods, and some of them are implemented in SWCompression.
For CocoaPods configurations there are some sort of 'optional dependencies' for such compression methods.

"Optional dependency" in this context means
that SWCompression/ZIP or SWCompression/7-Zip will support particular compression methods
only if a corresponding subspec is expicitly specified in your Podfile and installed.

List of "optional dependecies":

- For SWCompression/ZIP:
    - SWCompression/BZip2
    - SWCompression/LZMA
- For SWCompression/SevenZip:
    - SWCompression/BZip2
    - SWCompression/Deflate

__Note:__ If you use Carthage or Swift Package Manager you always have the full package
and ZIP and 7-Zip are built with Deflate, BZip2 and LZMA/LZMA2 support.

### Carthage

Add to your Cartfile `github "tsolomko/SWCompression"`.

Then run `carthage update`.

Finally, drag and drop `SWCompression.framework` from `Carthage/Build` folder
into the "Embedded Binaries" section on your targets' "General" tab in Xcode.

## Usage

### Basic Example

If you'd like to decompress "deflated" data just use:

```swift
// let data = <Your compressed data>
let decompressedData = try? Deflate.decompress(data: data)
```

However, it is unlikely that you will encounter deflated data outside of any archive.
So, in case of GZip archive you should use:

```swift
let decompressedData = try? GzipArchive.unarchive(archiveData: data)
```

### Handling Errors

Most SWCompression functions can throw an error and you are responsible for handling them.
If you look at list of available error types and their cases, you may be frightened by their number.
However, most of these cases (such as `XZError.wrongMagic`) exist for diagnostic purposes.

Thus, you only need to handle the most common type of error for your archive/algorithm. For example:

```swift
do {
    // let data = <Your compressed data>
    let decompressedData = try XZArchive.unarchive(archive: data)
} catch let error as XZError {
    <handle XZ related error here>
} catch let error {
    <handle all other errors here>
}
```

Or, if you don't care about errors at all, use `try?`.

### Documentation

Every function or type of SWCompression's public API is documented.
This documentation can be found at its own [website](http://tsolomko.github.io/SWCompression).

### Sophisticated example

There is a small command-line program, "swcomp", which is included in this repository in "Sources/swcomp".
To build it you need to uncomment several lines in "Package.swift" and run `swift build -c release`.

## Contributing

Whether you find a bug, have a suggestion, idea or something else,
please [create an issue](https://github.com/tsolomko/SWCompression/issues) on GitHub.

In case you have encoutered a bug, it would be especially helpful if you attach a file (archive, etc.)
that caused the bug to happen.

If you'd like to contribute code, please [create a pull request](https://github.com/tsolomko/SWCompression/pulls) on GitHub.

### Executing tests locally

If you want to run tests on your computer, you need to do some additional steps after cloning this repository:

```bash
git submodule update --init --recursive
cd Tests/Test\ Files
git lfs pull
```

These commands fetch example archives and other files which are used for testing.
These files are stored in a [separate repository](https://github.com/tsolomko/SWCompression-Test-Files).
Git LFS is used for storing them which is the reason for having them in the separate repository,
since Swift Package Manager have some problems with Git LFS-enabled repositories
(it requires installing git-lfs _locally_ with `--skip-smudge` option to solve these problems).

## Performace

Usage of whole module optimizations is recommended for best performance.
These optimizations are enabled by default for Release configurations.

[Tests Results](Tests/Results.md) document contains results of performance testing of various functions.

## Why?

First of all, existing solutions for work with compression, archives and containers have some problems.
They might not support some particular compression algorithms or archive formats and they all have different APIs,
which sometimes can be slightly "unfriendly" to users.
This project attempts to provide missing (and sometimes existing) functionality through unified API,
which is easy to use and remember.

Secondly, it may be important to have a compression framework written completely in Swift,
without relying on either system libraries or solutions implemented in different languages.
Additionaly, since SWCompression is written fully in Swift without Objective-C,
it can also be compiled on __Linux__.

## Future plans

- Performance...
- Better Deflate compression.
- Something else...

## References

- [pyflate](http://www.paul.sladen.org/projects/pyflate/)
- [Deflate specification](https://www.ietf.org/rfc/rfc1951.txt)
- [GZip specification](https://www.ietf.org/rfc/rfc1952.txt)
- [Zlib specfication](https://www.ietf.org/rfc/rfc1950.txt)
- [LZMA SDK and specification](http://www.7-zip.org/sdk.html)
- [XZ specification](http://tukaani.org/xz/xz-file-format-1.0.4.txt)
- [Wikipedia article about LZMA](https://en.wikipedia.org/wiki/Lempel–Ziv–Markov_chain_algorithm)
- [.ZIP Application Note](http://www.pkware.com/appnote)
- [ISO/IEC 21320-1](http://www.iso.org/iso/catalogue_detail.htm?csnumber=60101)
- [List of defined ZIP extra fields](https://opensource.apple.com/source/zip/zip-6/unzip/unzip/proginfo/extra.fld)
- [Wikipedia article about TAR](https://en.wikipedia.org/wiki/Tar_(computing))
- [Pax specification](http://pubs.opengroup.org/onlinepubs/9699919799/utilities/pax.html)
- [Basic TAR specification](https://www.gnu.org/software/tar/manual/html_node/Standard.html)
- [Apache Commons Compress](https://commons.apache.org/proper/commons-compress/)
- [A walk through the SA-IS Suffix Array Construction Algorithm](http://zork.net/~st/jottings/sais.html)
- [Wikipedia article about BZip2](https://en.wikipedia.org/wiki/Bzip2)
