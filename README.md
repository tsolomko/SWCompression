# SWCompression
[![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/tsolomko/SWCompression/master/LICENSE)
[![CocoaPods](https://img.shields.io/cocoapods/p/SWCompression.svg)](https://cocoapods.org/pods/SWCompression)
[![Swift 3](https://img.shields.io/badge/Swift-3.1.1-lightgrey.svg)](https://developer.apple.com/swift/)
[![Build Status](https://travis-ci.org/tsolomko/SWCompression.svg?branch=develop)](https://travis-ci.org/tsolomko/SWCompression)
[![codecov](https://codecov.io/gh/tsolomko/SWCompression/branch/develop/graph/badge.svg)](https://codecov.io/gh/tsolomko/SWCompression)

[![CocoaPods](https://img.shields.io/cocoapods/v/SWCompression.svg)](https://cocoapods.org/pods/SWCompression)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

A framework which contains implementations of (de)compression algorithms and functions which parse various archives and containers.

__Developed with Swift.__

Why have you made this framework?
----------------------------------------
There are a couple of reasons for this.

The main reason is that it is very educational and somewhat fun.

Secondly, if you are a Swift developer and you want to compress/decompress something in your project
you have to use either wrapper around system libraries (which is probably written in Objective-C)
or you have to use built-in Compression framework.
You might think that last option is what you need, but, frankly
that framework has a bit complicated API and somewhat questionable choice of supported compression algorithms.
And yes, it is also in Objective-C.

And here comes SWCompression: no Objective-C, pure Swift.

Features
----------------
- Containers:
  - ZIP
  - TAR
- Decompression algorithms:
  - LZMA/LZMA2
  - Deflate
  - BZip2
- Compression algorithms:
  - Deflate
- Archives:
  - XZ
  - GZip
  - Zlib
- Platform independent.
- _Written with Swift only._

By the way, it seems like GZip, Deflate and Zlib implementations are __specification compliant__.

Installation
----------------

SWCompression can be integrated into your project either using CocoaPods, Carthage or Swift Package Manager.

##### CocoaPods
Add to your Podfile `pod 'SWCompression'`.

There are several sub-podspecs in case you need only parts of framework's functionality.
Available subspecs:

  - SWCompression/LZMA
  - SWCompression/XZ
  - SWCompression/Deflate
  - SWCompression/Gzip
  - SWCompression/Zlib
  - SWCompression/BZip2
  - SWCompression/ZIP
  - SWCompression/TAR

You can add some or all of them instead of `pod 'SWCompression'`

Also, do not forget to include `use_frameworks!` line in your Podfile.

To complete installation, run `pod install`.

_Note:_ Actually, there is one more subspec (SWCompression/Common) but it does not contain any end-user functions.
It is included in every other subspec and should not be specified directly in Podfile.

##### Carthage
Add to  your Cartfile `github "tsolomko/SWCompression"`.

Then run `carthage update`.

Finally, drag and drop `SWCompression.framework` from `Carthage/Build` folder into the "Embedded Binaries" section on your targets' "General" tab.

##### Swift Package Manager
Add to you package dependecies `.Package(url: "https://github.com/tsolomko/SWCompression.git")`, for example like this:

```swift
import PackageDescription

let package = Package(
    name: "PackageName",
    dependencies: [
        .Package(url: "https://github.com/tsolomko/SWCompression.git", majorVersion: 3)
    ]
)
```

More info about SPM you can find at [Swift Package Manager's Documentation](https://github.com/apple/swift-package-manager/tree/master/Documentation).

SWCompression/ZIP and compression methods
-----------------------------------------
Deflate is a default compression method of ZIP containers.

This means, that if you use CocoaPods, when installing SWCompression/ZIP it will install SWCompression/Deflate as a dependency.

However, ZIP containers can also support LZMA and BZip2.
So if you want to enable them in your Pods configuration you need to include SWCompression/LZMA and/or SWCompression/Deflate.

If you use Carthage or Swift Package Manager you always have the full package,
and ZIP will be built with both BZip2 and LZMA support.

Usage
-----
#### Basics
If you'd like to decompress "deflated" data just use:

```swift
let data = try! Data(contentsOf: URL(fileURLWithPath: "path/to/file"),
                     options: .mappedIfSafe)
let decompressedData = try? Deflate.decompress(data: data)
```

_Note:_ It is __highly recommended__ to specify `Data.ReadingOptions.mappedIfSafe`,
especially if you are working with large files, so you don't run out of system memory.

However, it is unlikely that you will encounter deflated data outside of any archive.
So, in case of GZip archive you should use:

```swift
let decompressedData = try? GzipArchive.unarchive(archiveData: data)
```

One final note: every SWCompression function can throw an error and
you are responsible for handling them.

#### Documentation
Every function or class of public API of SWCompression is documented.
This documentation can be found at its own [website](http://tsolomko.github.io/SWCompression).

#### Handling Errors
If you look at list of available error types and their cases, you may be frightened by their number.
However, most of these cases (such as `XZError.WrongMagic`) exist for diagnostic purposes.

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

#### Sophisticated example
There is a small program, [swcomp](https://github.com/tsolomko/swcomp),
which uses SWCompression for unarchiving several types of archives.

About performace
----------------
__TL;DR__ Constantly trying to improve performance;
use whole module optimizations, which are enabled by default for Release configurations.

Further thoughts, details and notes about performance you can read in a [separate document](Performance.md).

[Tests Results](Tests/Results.md) document contains results of performance testing of various algorithms.

Known issues
------------
- `wrongCRC` and `wrongCheck` errors for XZ and GZip multi-member archives
contain only last member's data as their associated value instead of all processed members.

Comment: Philosophy for such errors is that by the time these errors are thrown,
decompression was already performed,
so we can still provide the result of decompression to the caller.
It is intended to fix this problem, but solution requires backwards-incompatible API changes so it is delayed until 4.0 release.

Future plans
-------------
- Better Deflate compression.
- 7zip containers.
- BZip2 compression.
- Something else...

References
-----------
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
