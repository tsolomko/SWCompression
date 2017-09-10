# About performance

Details about current state of SWCompression's performance are discussed here
as well as what is going to be done in the future to improve it.

## General comments

First, overall lower performance is expected compared to highly optimized low-level
C implementations of corresponding algorithms.
This is the nature of low-level implementations.
That being said there are certainly some things that can be improved
to perform algorithms in efficient ways.

This leads us to a question: what is 'efficiency'?
And the answer is quite interesting.
Compression is mostly used to reduce size of data, from very big to comparatively small.
Thus, implementations of compression and decompression algorithms SHOULD scale well
with the increase of input's size.
Moreover, it is probably acceptable to sacrifice speed for relatively redundant amounts of data
and simultaneously noticeably improve 'efficiency' defined above.

So to maintain high performance we need to do our algorithms in an 'efficient' way.

But there is a second part of good performance and it is the language itself.
Speed gain is expected to follow new releases of Swift and its compiler.
For example, Swift 3.1 came with a significant portion of performance improvements to `Data`.
Swift 4.0 will contain further improvements and this project is going to make use of them.

Another example of how language improves performance is compiler optimizations.
Swift compiler uses 'whole module optimization' for Release configurations and
this makes a big difference. You can check this out in [tests results](Tests/Results.md).

## Deflate Decompression

Current state of perfomance is __good__.

Fun fact: there were at least two times in history of development of SWCompression,
when performance increase was achived by reimplementing Huffman encoding in a smarter way.

## Deflate Compression

Current state of performance is __mediocre__.
This is caused by incomplete implementation of some parts of algorithm.
Moreover, there are slight overusage of memory during duplicate string elimination,
which is caused by not really limiting size of a dictionary.

## BZip2 Decompression

Current state of performance is __average__.
Most inefficient part of algorithm is BW transormation.
Though theoretically current implementanion of this transfrom should be fast,
there are still two problems causing performance issues:

1. Not very fast built-in `indexOf(:)` function.
    This was fixed in 3.1.0 of SWCompression in a way which doesn't use this function
    and trades some performance for small data sizes in favor of better scaling.
2. Not really fast built-in `sorted()` function.
    Apart from that, Swift doesn't contain stable sorting alogrithms
    which is somewhat important for efficiency.

## XZ/LZMA/LZMA2 Decompression

Current state of perfomance is __good__.

## TAR Parsing

There are some scaling problems
(problems which manifest themselves when opening big TAR archives).
These problems are partially caused by Swift's `String` performance,
which is expected to be improved in Swift 4.0.
