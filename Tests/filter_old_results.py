#!/usr/bin/env python3
import re
import sys

filename = sys.argv[1]
test_name = sys.argv[2]
inp = open(filename)
content = inp.read()

p = re.compile('(?:' + test_name + '.test\d average: )(\d{1,3}\.\d{1,3})')
matches = p.findall(content)
output = "|"
for match in matches:
    output += match + "|"
print(output)
inp.close()
