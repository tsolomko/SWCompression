# Changelog
v3.0.0
----------------
- All errors have been renamed, so they conform to Swift Naming Conventions (lowerCamelCase).
- Added `Container` and `ContainerEntry` protocols.
- Most methods have their arguments' labels renamed to make usage shorter.
- Most documentation have been edited to improve readability.
- Multiple files with results of performance tests replaced with consolidated one.
- Enabled support for LZMA and BZip2 compression algorithms.
- `ZipEntry` now conforms to `ContainerEntry` protocol.
- This also means that entry's data is now provided through `ZipEntry.data()` instead of `ZipContainer`'s function.
- Improved detection of directories if ZIP container was created on MS-DOS or UNIX-like systems.
- `ZipError.wrongCRC32` now contains entry's data as associated value.
- Fixed a problem where Zip64 sized fields weren't used during processing of Data Descriptor.
- Added some measures to prevent crashes when it is impossible to read ZIP text fields (file name or comment) in UTF-8 encoding
- Added support for TAR containers in various format versions.
- Now `GzipArchive.unarchive` function unarchives only first 'member' of archive.
- Added support for GZip archive's option in `archive` function.
- `GzipHeader.modificationTime` is now Optional.
- `GzipHeader.originalFileName` renamed to `GzipHeader.fileName`.
- Added `GzipHeader.isTextFile` property which corresponds to same named flag in archive's header.
- Now `XZArchive.unarchive` function unarchives only first stream of archive.
- Check for xz archive's footer's 'magic' bytes is now performed at the beginning of processing.
- XZ header's checksum is now checked before parsing reserved flags.
- BZip2 now performs CRC32 check for decompressed data.
- Removed internal `LZMAOutWindow` auxiliary class.

v2.4.3
----------------
- Fixed incorrect calculation of header's checksum for GZip archives.

v2.4.2
----------------
- Fixed a problem, where ZipEntry.fileName was returning fileComment instead.

v2.4.1
----------------
- Lowered deployment targets versions for all (supported) Apple platforms.

v2.4.0
----------------
- Reduced memory usage in some cases.
- Added Zlib archiving function.

v2.3.0
----------------
- Improved Deflate compression performance.
- Added GZip archiving function.
- Fixed a problem when Deflate uncompressed blocks were created with one extra byte.

v2.2.2
----------------
- Fixed problem with zero-length uncompressed blocks.

v2.2.1
----------------
- Now creates uncompressed block instead of huffman if it will provide better results (in terms of "compression").
- Small internal changes.

v2.2.0
----------------
- Somewhat limited support for Deflate compression.
- API for parsing ZIP entries.

v2.1.0
----------------
- ZIP containers support.
- HuffmanTree is no longer part of SWCompression/Common.
- Updated documentation.

v2.0.1
----------------
- Fixed incorrect reading adler32 checksum from zlib archives.
- Removed LZMA_INFO and LZMA_DIAG build options.
- (2.0.0) GZip archives with multiple 'members' are now parsed correctly.

v2.0.0
----------------
- LZMA decompression.
- XZ unarchiving.
- Once again performance improvement (this time for real).
- Added public API functions for reading gzip/zlib headers.
- Added documentation.
- Added checksums support.
- Added new errors subtypes.
- Added two build options for diagnostical use.
- Rephrased comments to public API.

v1.2.2
----------------
- Small performance improvement.

v1.2.1
----------------
- Removed HuffmanLength.
- Rewritten DataWithPointer.
- Added performance tests.

v1.2.0
----------------
- Reimplemented Huffman Coding using a tree-like structure.
- Now only DataWithPointer is used during the processing.

v1.1.2
----------------
- Fixed memory problem in Deflate.
- Improved overall performance.

v1.1.1
----------------
- Fixed problems when building with Swift Package Manager.
- Added missing files to watchOS scheme.
- Every release on github now will have an archive with pre-built framework.
- Added info about performance to README.

v1.1.0
----------------
- Added BZip2 decompression.
- Introduced subspecs with parts of functionality.
- Additional performance improvements.
- Fixed potential memory problems.
- Added a lot of (educational) comments for Deflate

v1.0.3
----------------
Great performance improvements (but there is still room for more improvements).

v1.0.2
----------------
- Fixed a problem when decompressed amount of data was greater than expected.
- Performance improvement.

v1.0.1
----------------
Fixed several crashes caused by mistyping and shift 'overflow' (when it becomes greater than 15).

v1.0.0
----------------
Initial release, which features support for Deflate, Gzip and Zlib decompression.
