import re
import sys

filename = sys.argv[1]
out_filename = sys.argv[2]
inp = open(filename)
content = inp.read()

p = re.compile('( average: \d{1,3}\.\d{1,3})|(\w{3,7}\.test\d)')
matches = p.findall(content)
f = open(out_filename, 'w')
for i, match in enumerate(matches):
    for s in match:
        if s != "":
            f.write(s)
            if i % 2 != 0:
                f.write("\n")
f.close()
inp.close()
