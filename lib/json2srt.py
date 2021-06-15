#!/usr/bin/python3
# Usage: python3 json2srt.py polly_output.json srt_file.srt
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

import json
import os
import sys

SUBTITLES_INTERVAL_SECONDS = 1
#test comment.
def getTimeCode(time_seconds):
	seconds, mseconds = str(time_seconds).split('.')
	mins = int(seconds) / 60
	tseconds = int(seconds) % 60
	return str( "%02d:%02d:%02d,%03d" % (00, mins, tseconds, int(0) ))

json_file = sys.argv[1]
srt_file = sys.argv[2]

i = 0
with open(json_file, 'r') as f:
	line = f.readline()
	while line:
		with open('tmp' + str(i) + '.json', 'w') as g:
			print(line, file=g)
		line = f.readline()
		num = i
		i+=1

timecode = []
message = []
i = 0
while i <= num:
	with open('tmp' + str(i) + '.json', 'r') as f:
		json_load = json.load(f)
		time_seconds1 = float(json_load['time'] / 1000)
		time_seconds2 = time_seconds1 + SUBTITLES_INTERVAL_SECONDS
		timecode.append(getTimeCode(time_seconds1))
		timecode.append(getTimeCode(time_seconds2))
		message.append(json_load['value'])
	os.remove('tmp' + str(i) + '.json')
	i+=1

i = 0
with open(srt_file, 'w') as f:
	if num == 0:
		print(i+1, '\n', '00:00:00,500', ' --> ', timecode[0], '\n', message[i], sep='', file=f)
	else:
		print(i+1, '\n', '00:00:00,500', ' --> ', timecode[i*2+2], '\n', message[i], '\n', sep='', file=f)
		i+=1
		while i <= num:
			if i == num:
				print(i+1, '\n', timecode[i*2+1], ' --> ', timecode[0], '\n', message[i], sep='', file=f)
			else:
				print(i+1, '\n', timecode[i*2+1], ' --> ', timecode[i*2+2], '\n', message[i], '\n', sep='', file=f)
			i+=1

