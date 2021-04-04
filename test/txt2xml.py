#!/usr/bin/python3
# Usage: python3 txt2xml.py xml_txt

import sys

xml_txt = sys.argv[1]

i = 0
with open(xml_txt, 'r') as f:
    line = f.readline()
    while line:
        if line == '<?xml version="1.0" encoding="UTF-8"?>\n':
                    i+=1
        with open('xml/' + str(int(i)) + '.xml', 'a') as g:
            print(line, end='', file=g)
        line = f.readline()
