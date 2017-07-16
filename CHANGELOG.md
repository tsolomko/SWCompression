# Changelog
v3.2.0
----------------
- Split source files.
- Removed SWCompression/Common subpodspec.
- Moved test files into separate repository as a submodule.
    - Fixed problem with Swift Package Manager requirement to disable smudge-filter of git-lfs.
- Support creation time for TarEntries.
- Add support for ZIP standardized CP437 encoding of string fields.
    - Fallback to UTF-8 if this encoding is unavailable on the platform.
    - Fallback to UTF-8 if it is detected that string fields is in UTF-8.
        - Necessary, because Info-ZIP doesn't marks fields it creates with UTF-8 flag.
- Fixed problem with finding zip64 end of Central Directory locator.
- Fixed problem with accessing `ZipEntry`'s data two or more times.
- Fixed problem with accessing data of BZip2 compressed `ZipEntry`.
- Fixed problem with reading zip64 data descriptor.

v3.1.3
----------------
- Added support for GNU LongLinkName and LongName extensions of TAR format.
- Added support for modification timestamp from extended timestamps ZIP extra field.

v3.1.2
----------------
- `wrongUstarVersion` error is no longer incorrectly thrown for GNU tar containers.

v3.1.1
----------------
- Permissions attributes for TarEntry are now base-10.
- Now throws `fieldIsNotNumber` error when encounters non-number required field in TAR header.
- Slightly improved documentation.

v3.1.0
----------------
- Added support for multi-member GZip archives.
- Added support for multi-stream XZ archives.
- Added property which allows access various entry's attributes for both Tar and ZIP.
- Several Container/Zip/TarEntry's properties are now considered deprecated.
- ZipEntry now provides access to modification time, posix permission and entry type using the new `entryAttributes` property.
- Added support for PAX link path.
- Fixed several problems with decompressing files compressed into ZIP container using LZMA.
- Fixed discarding ZIP containers with `wrongVersion` error when they contain LZMA or BZip2 compressed files.
- Encrypted ZIP containers should now be detected properly.
- `ZipError.compressionNotSupported` is now only thrown when trying to get entry's data and not when just opening the archive.
- Text fields from GZip header are now decoded with correct encoding.
- Improved Deflate comrpession rate for some corner cases.
- Improved BZip2 performance for cases of big data sizes.

v3.0.1
----------------
- Significanty reduced memory usage and improved speed of Deflate compression.

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
