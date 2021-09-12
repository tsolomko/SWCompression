# Test Results

In this document you can find the results of benchmarking which was performed on Macbook Air, Retina, 13-inch, Early
2020 with 1,1 GHz Quad-Core Intel Core i5 CPU. The main purpose of these results is to track progress from version to
version.

## Changelog

__September 2021.__ The results are now listed in terms of speed (e.g. MB/s); the benchmarks for Deflate, BZip2 compression and
TAR container creation have been added; all previous results have been removed since newer hardware is now used; added
results for the `-Ounchecked` compiler option; the macOS version is now listed for results.

__April 2018.__ The first (zeroth, actually) iteration is now excluded from averages calculation since this iteration
has abnormally longer execution time than any of the following iterations. This exclusion led not only to (artificially)
improved results, but also to the increased quality of the results by reducing calculated uncertainty. In addition, the
averages are now computed over 10 iterations instead of 6.

__January 2018.__ SWCompression internal functionality related to reading/writing bits and bytes is published as a
separate framework, [BitByteData](https://github.com/tsolomko/BitByteData). The overall performance heavily depends on
the speed of reading and writing, and thus BitByteData's version, which is specified in a separate column in the tables
below, becomes relevant to benchmarking, since newer versions can contain performance improvements.

## Tests description

There are three different datasets for testing. When choosing them the intention was to have something
that represents real life situations. For obvious reasons these test files aren't provided anywhere
in the repository.

- Test 1: Git 2.15.0 Source Code.
- Test 2: Visual Studio Code 1.18.1 App for macOS.
- Test 3: Documentation directory from Linux kernel 4.14.2 Source Code.

All tests were run using swcomp's "benchmark" command. SWCompression (and swcomp) were compiled
using "Release" configuration.

__Note:__ External commands used to create compressed files were run using their default sets of options.

__Note:__ All results are averages over 10 iterations. If the uncertainty is not listed it means that it is less than
10% in terms of the units listed.

## BZip2 Decompress

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.6.0|2.0.1|11.5.2|5.4.2|2.764 MB/s|2.973 MB/s|2.410 MB/s|
|4.6.0-unchecked|2.0.1|11.5.2|5.4.2|3.279 ± 0.429 MB/s|4.361 ± 0.306 MB/s|3.169 ± 0.180 MB/s|

## XZ Unarchive (LZMA/LZMA2 Decompress)

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.6.0|2.0.1|11.5.2|5.4.2|5.246 ± 0.279 MB/s|5.543 ± 0.143 MB/s|5.322 ± 0.26 MB/s|
|4.6.0-unchecked|2.0.1|11.5.2|5.4.2|6.015 ± 0.319 MB/s|6.374 ± 0.143 MB/s|5.841 ± 0.212 MB/s|

## GZip Unarchive (Deflate Decompress)

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.6.0|2.0.1|11.5.2|5.4.2|5.946 ± 0.432 MB/s|6.034 ± 0.175 MB/s|6.071 ± 0.25 MB/s|
|4.6.0-unchecked|2.0.1|11.5.2|5.4.2|8.562 ± 0.388 MB/s|9.908 ± 0.204 MB/s|8.286 ± 0.250 MB/s|

## BZip2 Compress

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.6.0|2.0.1|11.5.2|5.4.2|3.540 MB/s|2.862 MB/s|4.253 MB/s|
|4.6.0-unchecked|2.0.1|11.5.2|5.4.2|3.816 MB/s|3.060 MB/s|4.647 MB/s|

## Deflate Compress

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.6.0|2.0.1|11.5.2|5.4.2|12.177 ± 0.259 MB/s|8.809 MB/s|13.594 ± 0.355 MB/s|
|4.6.0-unchecked|2.0.1|11.5.2|5.4.2|12.914 ± 0.355 MB/s|9.361 MB/s|15.020 ± 0.277 MB/s|

## 7-Zip Info Function

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.6.0|2.0.1|11.5.2|5.4.2|77.072 ± 6.625 MB/s|111.246 ± 4.855 MB/s|38.721 ± 2.681 MB/s|
|4.6.0-unchecked|2.0.1|11.5.2|5.4.2|82.367 ± 7.381 MB/s|116.923 ± 3.812 MB/s|38.519 ± 2.988 MB/s|

## TAR Info Function

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.6.0|2.0.1|11.5.2|5.4.2|967.792 ± 58.436 MB/s|1.006 GB/s|217.082 ± 19.783 MB/s|
|4.6.0-unchecked|2.0.1|11.5.2|5.4.2|1.073 ± 0.115 GB/s|1.053 GB/s|246.854 ± 6.763 MB/s|

## ZIP Info Function

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.6.0|2.0.1|11.5.2|5.4.2|597.002 ± 75.017 MB/s|1.941 ± 0.135 GB/s|389.626 ± 22.006 MB/s|
|4.6.0-unchecked|2.0.1|11.5.2|5.4.2|685.266 ± 53.895 MB/s|2.147 GB/s|420.461 ± 15.156 MB/s|

## TAR Create Function

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.6.0|2.0.1|11.5.2|5.4.2|139.649 ± 8.310 MB/s|446.101 ± 21.476 MB/s|215.556 ± 17.5 MB/s|
|4.6.0-unchecked|2.0.1|11.5.2|5.4.2|142.681 ± 5.664 MB/s|459.403 ± 17.862 MB/s|220.238 ± 3.476 MB/s|
