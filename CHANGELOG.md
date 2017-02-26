# Changelog
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
