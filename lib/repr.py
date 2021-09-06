#!/usr/bin/python3


import os
import sys


input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, 'r') as f:
	data = f.read()
	with open(output_file, 'w') as g:
		print(repr(data), file=g)

