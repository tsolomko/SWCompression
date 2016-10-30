# SWCompression
A framework which contains native (*written in Swift*)
implementations of some compression algorithms.

### Why have you made compression framework?
There are a couple of reasons for this.

The main reason is that it is very educational and somewhat fun.

Secondly, if you are a Swift developer and you want to compress/decompress something in your project
you have to use either wrapper around system libraries (which is probably written in Objective-C)
or you have to use built-in Compression framework.
You might think that last option is what you need, but, frankly
that framework has a bit complicated API and somewhat questionable choice of supported compression algorithms. And yes, it is also in Objective-C.

And here comes SWCompression: no Objective-C, pure Swift.

### Features
- Decompress data which were compressed with DEFLATE algorithm.
- Extract data from GZip archives.
- Unarchive zlib compressed data.
- _Swift only_

By the way, it seems like GZip and Deflate decompressor implementations are specification compliant.

### Installation

##### CocoaPods
Add to your Podfile `pod 'SWCompression'`.

Also, do not forget to have `use_frameworks!` line in the Podfile.

To complete installation, run `pod install`.

##### Carthage
Add to  your Cartfile `github "tsolomko/SWCompression"`.

Then run `carthage update`.

Finally, drag and drop `SWCompression.framework` from `Carthage/Build` folder into the "Embedded Binaries" section on your targets' "General" tab.

### Usage
If you'd like to decompress "deflated" data just use:
```swift
let data = try! Data(contentsOf: URL(fileURLWithPath: "path/to/file"))
let decompressedData = try? Deflate.decompress(compressedData: data)
```
**Note:** you should properly handle possible errors in loading data from file
and define yourself if you need any `Data.ReadingOptions`.

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

### Future plans
- BZip2 decompression support.
- Deflate compression.
- BZip2 compression.
- Something else...

### References
The main source of information was [pyflate](http://www.paul.sladen.org/projects/pyflate/) —
python implementation of GZip and BZip2.

There are also several specifications which were also very useful:
- [Deflate specification](https://www.ietf.org/rfc/rfc1951.txt)
- [GZip specification](https://www.ietf.org/rfc/rfc1952.txt)
- [Zlib specfication](https://www.ietf.org/rfc/rfc1950.txt)
