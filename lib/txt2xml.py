#!/usr/bin/python3
# Usage: python3 txt2xml.py xml_txt
#
# Copyright (C) 2021 Hirofumi Kojima
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import sys

xml_txt = sys.argv[1]
XML_HEADER = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"

i = 0
with open(xml_txt, 'r') as f:
    line = f.readline()
    while line:
        if line == XML_HEADER:
                i+=1
        with open('xml/' + str(int(i)) + '.xml', 'a') as g:
                print(line, end='', file=g)
        line = f.readline()

