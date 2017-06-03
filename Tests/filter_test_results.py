#!/usr/bin/env python3
import re
import sys

# Loading file with output from Xcode.
filename = sys.argv[1]
inp = open(filename)
content = inp.read()
inp.close()

# First, we filter the performance tests output.
p = re.compile('( average: \d{1,3}\.\d{1,3})|(\w{2,9}\.test\d)')
matches = p.findall(content)
# We write them into a temporary string.
perf_tests_output = ""
for i, match in enumerate(matches):
    for s in match:
        if s != "":
            perf_tests_output += s
            if i % 2 != 0:
                perf_tests_output += "\n"

# Supported tests.
tests = ["bz2", "deflate", "gz", "xz"]

# We prepend every final string output with version number from args.
version = sys.argv[2]

# Then we split this output into table rows for Results.md file.
# We print them into standard output.
for test in tests:
    p = re.compile('(?:' + test + '.test\d average: )(\d{1,3}\.\d{1,3})')
    matches = p.findall(perf_tests_output)
    output = test + ": |" + version + "|"
    for i, match in enumerate(matches):
        if i >= 7: # We don't need test8 and test9.
            break
        output += match + "|"
    print(output)
