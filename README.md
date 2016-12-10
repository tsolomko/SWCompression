# SWCompression
[![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/tsolomko/SWCompression/master/LICENSE) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) [![Build Status](https://travis-ci.org/tsolomko/SWCompression.svg?branch=develop)](https://travis-ci.org/tsolomko/SWCompression) [![codecov](https://codecov.io/gh/tsolomko/SWCompression/branch/develop/graph/badge.svg)](https://codecov.io/gh/tsolomko/SWCompression)

A framework which contains native (*written in Swift*)
implementations of some compression algorithms.

Why have you made compression framework?
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
- (De)compression algorithms:
  - Deflate
  - BZip2
- Archives:
  - GZip
  - Zlib
- Platform independent.
- _Swift only_

By the way, it seems like GZip and Deflate decompressor implementations are **specification compliant**.

Installation
----------------

SWCompression can be integrated into your project either using CocoaPods, Carthage or Swift Package Manager.

##### CocoaPods
Add to your Podfile `pod 'SWCompression'`.

Since 1.1.0 version of SWCompression there are several sub-podspecs
if you need only parts of functionality of SWCompression.
There are `pod 'SWCompression/GZip'`, `pod 'SWCompression/Zlib'`, `pod 'SWCompression/Deflate'` and `pod 'SWCompression/BZip2'` subspecs. You can add some or all of them instead of `pod 'SWCompression'`

Also, do not forget to have `use_frameworks!` line in the Podfile.

To complete installation, run `pod install`.

_Note:_ Actually, there is one more subspec (SWCompression/Common) but it does not contain any end-user functions. This subspec is included in other subspecs such as SWCompression/GZip and should not be specified directly in Podfile.

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
        .Package(url: "https://github.com/tsolomko/SWCompression.git", majorVersion: 1)
    ]
)
```

More info you may find at [Swift Package Manager's Documentation](https://github.com/apple/swift-package-manager/tree/master/Documentation).

Usage
-------
If you'd like to decompress "deflated" data just use:
```swift
let data = try! Data(contentsOf: URL(fileURLWithPath: "path/to/file"),
                     options: .mappedIfSafe)
let decompressedData = try? Deflate.decompress(compressedData: data)
```
_Note:_ It is __highly recommended__ to specify `Data.ReadingOptions.mappedIfSafe`,
especially if you are working with large files,
so you don't run out of system memory.

However, it is unlikely that you will encounter deflated data outside of any archive.
So, in case of GZip archive you should use:
```swift
let decompressedData = try? GzipArchive.unarchive(archiveData: data)
```

And, finally, for zlib the corresponding code is:
```swift
let decompressedData = try? ZlibArchive.unarchive(archiveData: data)
```

One final note: every unarchive/decompress function can throw an error and
you are responsible for handling them.

Why is it so slow?
-------------
Is it?

The problem is that if SWCompression is built with 'Debug' configuration for some reason the performance is really bad.
However, if you use 'Release' configuration varoius optimizations start to take effect and decompression speed will be much better.
I don't know what is really happening, how Swift compiler works, etc., but bottomline is that you should REALLY use __'Release'__ builds of SWCompression.

_Note:_ There are (mostly, were) performance problems caused by implementation (you can check out v1.0.0, if you want to know what is 'slow'!), but as the time goes on I am trying to find new ways to optimize the code.

Future plans
-------------
- Performance improvement.
- LZMA decompression.
- XZ decompression.
- Tar unarchiving.
- Deflate compression.
- BZip2 compression.
- Something else...

References
-----------
The main source of information was [pyflate](http://www.paul.sladen.org/projects/pyflate/) —
python implementation of GZip and BZip2.

There are also several specifications which were also very useful:
- [Deflate specification](https://www.ietf.org/rfc/rfc1951.txt)
- [GZip specification](https://www.ietf.org/rfc/rfc1952.txt)
- [Zlib specfication](https://www.ietf.org/rfc/rfc1950.txt)
