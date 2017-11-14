# SWCompression

[![Swift 4](https://img.shields.io/badge/Swift-4.0-blue.svg)](https://developer.apple.com/swift/)
[![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/tsolomko/SWCompression/master/LICENSE)
[![Build Status](https://travis-ci.org/tsolomko/SWCompression.svg?branch=develop)](https://travis-ci.org/tsolomko/SWCompression)

A framework with (de)compression algorithms and functions for processing various archives and containers.

## What

SWCompression - is a framework with a collection of different functions to:

1. Decompress (and sometimes compress) using different algorithms.
2. Read (and sometimes write) different archives.
3. Read containers such as ZIP, TAR and 7-Zip.

In the tables below full list of available features is presented.
"TBD" means that feature is planned but not implemented (yet).

|               | Deflate            | BZip2              | LZMA/LZMA2         |
| ------------- | ------------------ | ------------------ | ------------------ |
| Compression   | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Decompression | :white_check_mark: | :white_check_mark: | TBD                |

|       | Zlib               | GZip               | XZ                 |
| ----- | ------------------ | ------------------ | ------------------ |
| Read  | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Write | :white_check_mark: | :white_check_mark: | TBD                |

|       | ZIP                | TAR                | 7-Zip              |
| ----- | ------------------ | ------------------ | ------------------ |
| Read  | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Write | TBD                | TBD                | TBD                |

And, by the way, SWCompression is _written with Swift only._

## Installation

SWCompression can be integrated into your project either using Swift Package Manager, CocoaPods or Carthage.

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

More info about SPM you can find at [Swift Package Manager's Documentation](https://github.com/apple/swift-package-manager/tree/master/Documentation).

### CocoaPods

Add to your Podfile `pod 'SWCompression'`.

There are several sub-podspecs in case you need only parts of framework's functionality.
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

You can add some of them instead of `pod 'SWCompression'`

Also, do not forget to include `use_frameworks!` line in your Podfile.

To complete installation, run `pod install`.

#### Options for CocoaPods users

Both ZIP and 7-Zip containers have compression method which is most likely to be used when compressing files into them.
This is Deflate for ZIP and LZMA/LZMA2 for 7-Zip.
Thus, SWCompression/ZIP subspec have SWCompression/Deflate subspec as a dependency
and SWCompression/LZMA subspec as a dependency for SWCompression/SevenZip.

But both these containers support other compression methods, some of them are implemented in SWCompression.
For CocoaPods configurations there are some sort of 'optional dependencies' for such compression methods.

'Optional dependency' in this context means
that SWCompression/ZIP or SWCompression/7-Zip will support particular compression methods
only if a corresponding subspec is expicitly specified in your Podfile and installed.

__List of 'optional dependecies'.__

For SWCompression/ZIP:

- SWCompression/BZip2
- SWCompression/LZMA

For SWCompression/SevenZip:

- SWCompression/BZip2
- SWCompression/Deflate

__Note:__ If you use Carthage or Swift Package Manager you always have the full package,
and ZIP will be built with both additional BZip2 and LZMA support
as well as 7-Zip will be build with both additional Deflate and BZip2 support.

### Carthage

Add to  your Cartfile `github "tsolomko/SWCompression"`.

Then run `carthage update`.

Finally, drag and drop `SWCompression.framework` from `Carthage/Build` folder
into the "Embedded Binaries" section on your targets' "General" tab.

## Usage

### Basics

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

One final note: every SWCompression function can throw an error and you are responsible for handling them.

### Documentation

Every function or class of public API of SWCompression is documented.
This documentation can be found at its own [website](http://tsolomko.github.io/SWCompression).

### Handling Errors

If you look at list of available error types and their cases, you may be frightened by their number.
However, most of these cases (such as `XZError.wrongMagic`) exist for diagnostic purposes.

Thus, you only need to handle the most common type of error for your archive/algorithm.
For example:

```swift
do {
  let data = try Data(contentsOf: URL(fileURLWithPath: "path/to/file"),
                      options: .mappedIfSafe)
  let decompressedData = XZArchive.unarchive(archive: data)
} catch let error as XZError {
  <handle XZ related error here>
} catch let error {
  <handle all other errors here>
}
```

### Sophisticated example

There is a small program, [swcomp](https://github.com/tsolomko/swcomp),
which uses SWCompression for unarchiving several types of archives.

## Performace

Usage of whole module optimizations is recommended for best performance.
These optimizations are enabled by default for Release configurations.

[Tests Results](Tests/Results.md) document contains results of performance testing of various algorithms.

## Running tests locally

If you want to run tests locally you need to clone this repository and do some additional steps:

```bash
git submodule update --init --recursive
cd Tests/Test\ Files
git lfs pull
```

These commands fetch example archives and other files which are used for testing.
These files are stored in a [separate repository](https://github.com/tsolomko/SWCompression-Test-Files).
Git LFS is also used for storing them which basically is the reason for having them in other repository.
Otherwise, using Swift Package Manager to install SWCompression is a bit challenging
(requires installing git-lfs _locally_ with `--skip-smudge` option to solve the problem).

## Why

First of all, existing solutions for work with compression, archives and containers have some problems.
They might not support some particular compression algorithms or archive formats and they all have different APIs,
which sometimes can be slightly "unfriendly" to use.
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
