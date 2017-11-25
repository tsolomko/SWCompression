# Test Results

In this document you can find the results of performance tests which were run on Macbook Pro, Late 2011.
The main purpose of them is to track the progress from version to version.

## Tests description

There are three different dataset for testing. When choosing them, I was trying to have something,
that represents real life situations. For obvious reasons these test files aren't provided anywhere
in the repository.

- Test 1: Git 2.15.0 Source Code.
- Test 2: Visual Studio Code 1.18.1 App for macOS.
- Test 3: Documentation directory from Linux kernel 4.14.2 Source Code.

All tests were run using swcomp's "perf-test" command. SWCompression (and swcomp) were compiled
using "Release" configuration.

## BZip2 Decompress

|Version|Test 1|Test 2|Test 3|
|---|---|---|---|
|4.0.0|6.821 ± 0.042|54.214 ± 1.398|7.255 ± 0.117|
|4.0.1|6.797 ± 0.080|54.046 ± 1.070|7.177 ± 0.029|

## XZ Unarchive (LZMA/LZMA2 Decompress)

|Version|Test 1|Test 2|Test 3|
|---|---|---|---|
|4.0.0|error|24.663 ± 2.349|2.904 ± 0.076|
|4.0.1|2.475 ± 0.067|23.507 ± 0.423|2.901 ± 0.049|

## GZip Unarchive (Deflate Decompress)

|Version|Test 1|Test 2|Test 3|
|---|---|---|---|
|4.0.0|4.007 ± 0.196|32.043 ± 0.581|4.303 ± 0.045|
|4.0.1|3.886 ± 0.100|32.390 ± 0.896|4.295 ± 0.040|

## 7-Zip Info Function

|Version|Test 1|Test 2|Test 3|
|---|---|---|---|
|4.0.0|0.270 ± 0.010|crash|0.601 ± 0.057|
|4.0.1|0.258 ± 0.003|0.601 ± 0.010|0.473 ± 0.008|

## TAR Info Function

|Version|Test 1|Test 2|Test 3|
|---|---|---|---|
|4.0.0|0.248 ± 0.172|1.563 ± 0.442|1.254 ± 0.277|
|4.0.1|0.187 ± 0.177|1.257 ± 0.404|1.016 ± 0.325|

## ZIP Info Function

|Version|Test 1|Test 2|Test 3|
|---|---|---|---|
|4.0.0|0.072 ± 0.065|0.669 ± 0.147|0.120 ± 0.081|
|4.0.1|0.076 ± 0.064|0.670 ± 0.142|0.123 ± 0.080|
