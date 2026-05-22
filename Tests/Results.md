# Test Results

In this document you can find the results of benchmarking which was performed on Macbook Air M4, 15-inch, 2025. The main
purpose of these results is to track progress from version to version.

## Changelog

__May 2026.__ Replaced the results due to a significant hardware upgrade.

__October 2021.__ Added uncertainties for the results where they were missing; added LZ4 compression and decompression
sections; compression results now also list compression ratio in brackets (for the default compression settings unless
indicated otherwise).

__September 2021.__ The results are now listed in terms of speed (e.g. MB/s); the benchmarks for Deflate, BZip2
compression and TAR container creation have been added; all previous results have been removed since newer hardware is
now used; added results for the `-Ounchecked` compiler option; the macOS version is now listed for results.

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

__Note:__ External commands used to create compressed files were executed with default options.

__Note:__ All results are averages over 10 iterations.

## BZip2 Decompress

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.8.6|2.0.4|26.2|6.2.3|5.225 ± 0.032 MB/s|5.997 ± 0.009 MB/s|5.172 ± 0.021 MB/s|
|4.9.0|2.1.0|26.5|6.3.2|5.495 ± 0.277 MB/s|6.538 ± 0.093 MB/s|5.455 ± 0.138 MB/s|

## XZ Unarchive (LZMA/LZMA2 Decompress)

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.8.6|2.0.4|26.2|6.2.3|13.722 ± 0.042 MB/s|14.311 ± 0.023 MB/s|13.447 ± 0.162 MB/s|
|4.9.0|2.1.0|26.5|6.3.2|12.712 ± 0.888 MB/s|14.273 ± 0.313 MB/s|14.009 ± 0.047 MB/s|

## GZip Unarchive (Deflate Decompress)

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.8.6|2.0.4|26.2|6.2.3|11.899 ± 0.067 MB/s|11.487 ± 0.078 MB/s|11.806 ± 0.094 MB/s|
|4.9.0|2.1.0|26.5|6.3.2|13.570 ± 0.015 MB/s|13.392 ± 0.014 MB/s|13.373 ± 0.068 MB/s|

## LZ4 Decompress

For LZ4 decompression we report results both for independent and dependent blocks, since
this setting may significantly affect performance.

### Independent blocks

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.8.6|2.0.4|26.2|6.2.3|54.521 ± 1.030 MB/s|70.316 ± 0.602 MB/s|50.517 ± 0.515 MB/s|
|4.9.0|2.1.0|26.5|6.3.2|54.635 ± 0.315 MB/s|70.268 ± 0.562 MB/s|51.792 ± 0.396 MB/s|

### Dependent blocks

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.8.6|2.0.4|26.2|6.2.3|52.712 ± 0.644 MB/s|69.514 ± 0.935 MB/s|49.180 ± 0.818 MB/s|
|4.9.0|2.1.0|26.5|6.3.2|53.845 ± 0.799 MB/s|70.483 ± 0.431 MB/s|51.268 ± 0.401 MB/s|

## Deflate Compress

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.8.6|2.0.4|26.2|6.2.3|36.484 ± 0.519 MB/s (2.540)|28.093 ± 0.478 MB/s (2.266)|39.824 ± 1.121 MB/s (2.831)|
|4.9.0|2.1.0|26.5|6.3.2|66.732 ± 0.256 MB/s (2.540)|46.724 ± 1.092 MB/s (2.266)|73.479 ± 0.286 MB/s (2.831)|

## BZip2 Compress

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.8.6|2.0.4|26.2|6.2.3|8.133 ± 0.146 MB/s (3.493)|5.878 ± 0.031 MB/s (2.635)|9.690 ± 0.098 MB/s (3.875)|
|4.9.0|2.1.0|26.5|6.3.2|9.235 ± 0.162 MB/s (3.493)|6.594 ± 0.017 MB/s (2.635)|11.074 ± 0.009 MB/s (3.875)|

## LZ4 Compress

For LZ4 compression we report results both for independent and dependent blocks, since
this setting may significantly affect performance.

### Independent blocks

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.8.6|2.0.4|26.2|6.2.3|92.564 ± 0.606 MB/s (2.620)|68.459 ± 0.367 MB/s (2.278)|96.908 ± 0.787 MB/s (2.981)|
|4.9.0|2.1.0|26.5|6.3.2|105.739 ± 1.363 MB/s (2.620)|76.388 ± 0.923 MB/s (2.278)|111.100 ± 6.260 MB/s (2.981)|

### Dependent blocks

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.8.6|2.0.4|26.2|6.2.3|91.005 ± 0.527 MB/s (2.622)|67.450 ± 0.180 MB/s (2.280)|95.715 ± 0.621 MB/s (2.983)|
|4.9.0|2.1.0|26.5|6.3.2|104.768 ± 1.075 MB/s (2.622)|75.345 ± 0.304 MB/s (2.280)|111.121 ± 1.698 MB/s (2.983)|

## 7-Zip Info Function

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.8.6|2.0.4|26.2|6.2.3|805.462 ± 4.777 MB/s|1.714 ± 0.004 GB/s|418.213 ± 1.013 MB/s|
|4.9.0|2.1.0|26.5|6.3.2|835.139 ± 4.655 MB/s|1.818 ± 0.007 GB/s|438.974 ± 1.137 MB/s|

## TAR Info Function

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.8.6|2.0.4|26.2|6.2.3|3.520 ± 0.059 GB/s|4.333 ± 0.017 GB/s|936.204 ± 8.830 MB/s|
|4.9.0|2.1.0|26.5|6.3.2|3.647 ± 0.038 GB/s|4.465 ± 0.061 GB/s|953.367 ± 6.691 MB/s|

## ZIP Info Function

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.8.6|2.0.4|26.2|6.2.3|2.223 ± 0.017 GB/s|6.524 ± 0.031 GB/s|1.373 ± 0.007 GB/s|
|4.9.0|2.1.0|26.5|6.3.2|2.134 ± 0.017 GB/s|6.272 ± 0.075 GB/s|1.327 ± 0.008 GB/s|

## TAR Create Function

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.8.6|2.0.4|26.2|6.2.3|525.215 ± 2.978 MB/s|831.375 ± 8.157 MB/s|1.823 ± 0.063 GB/s|
|4.9.0|2.1.0|26.5|6.3.2|602.061 ± 2.170 MB/s|962.294 ± 2.548 MB/s|2.134 ± 0.083 GB/s|

## TAR Reader

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.8.6|2.0.4|26.2|6.2.3|1.586 ± 0.017 GB/s|2.063 ± 0.020 GB/s|498.778 ± 3.265 MB/s|
|4.9.0|2.1.0|26.5|6.3.2|1.695 ± 0.022 GB/s|2.200 ± 0.011 GB/s|530.854 ± 2.667 MB/s|

## TAR Writer

|SWCompression<br>version|BitByteData<br>version|macOS<br>version|Swift<br>version|Test 1|Test 2|Test 3|
|:---:|:---:|:---:|:---:|---|---|---|
|4.8.6|2.0.4|26.2|6.2.3|36.198 ± 29.341 MB/s|61.920 ± 35.293 MB/s|196.107 ± 64.376 MB/s|
|4.9.0|2.1.0|26.5|6.3.2|46.998 ± 26.850 MB/s|72.109 ± 29.039 MB/s|216.273 ± 23.042 MB/s|
