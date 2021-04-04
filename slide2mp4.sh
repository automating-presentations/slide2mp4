#!/bin/bash
# Usage: slide2mp4.sh PDF_FILE TXT_FILE LEXICON_FILE OUTPUT_MP4 <"page_num1 page_num2...">
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


PDF_FILE=$1
TXT_FILE=$2
LEXICON_FILE=$3
OUTPUT_MP4=$4
PAGES=$5

XML_HEADER="<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
VOICE_ID="Mizuki"
DENSITY="300"
GEOMETRY="1280x720"
LEXICON_NAME="test"
FONT_NAME="NotoSansCJKjp-Medium"
FONT_SIZE="14"
FPS="25"


# rm -f json2srt.py list.txt txt2xml.py
# rm -rf json mp3 mp4 png srt xml


print_usage ()
{
	echo "Description:"
	echo "	$(basename $0) is a conversion tool, PDF slides to MP4 with audio and subtitles."
	echo "	$(basename $0) uses Amazon Polly, Text-to-Speech (TTS) service."
	echo "	$(basename $0) requires the following commands, aws polly, ffmpeg, gm convert, python3, xmllint."
	echo "Usage:"
	echo "	$(basename $0) PDF_FILE TXT_FILE LEXICON_FILE OUTPUT_MP4 <"page_num1 page_num2...">"
	echo "Options:"
	echo "	-h, --help    print this message."
	exit
}


if [ $# -ne 0 ]; then
	if [ $1 == "-h" ]; then
		print_usage
	elif [ $1 == "--help" ]; then
		print_usage
	fi
fi
if [ $# -ne 4 ]; then
	if [ $# -ne 5  ]; then
		echo "Too few or many arguments. Please check whether the number of arguments is 4 or 5."
		echo "Please check '$(basename $0) -h' or '$(basename $0) --help'."
		exit
	fi
fi


for i in $PDF_FILE $TXT_FILE; do file $i > check_$i.txt; done
CHECK_PDF=$(grep -i pdf check_$PDF_FILE.txt 2> /dev/null); rm -f check_$PDF_FILE.txt
CHECK_TXT=$(grep -i text check_$TXT_FILE.txt 2> /dev/null); rm -f check_$TXT_FILE.txt
xmllint $LEXICON_FILE 1> /dev/null 2> check_$LEXICON_FILE_error.txt
CHECK_XML=$(grep -i error check_$LEXICON_FILE_error.txt); rm -f check_$LEXICON_FILE_error.txt
if [ -z "$CHECK_PDF" ]; then
	echo "This is not PDF file. Please check PDF file."
	exit
elif [ -z "$CHECK_TXT" ]; then
	echo "This is not text file. Please check text file."
	exit
elif [ -n "$CHECK_XML" ]; then
	echo "XML file parse error. Please check xml file."
	exit
fi
echo "Format checking of input files is completed."


mkdir -p json mp3 mp4 png srt xml


cat $TXT_FILE |awk '/\<\?xml/,/\<\/speak\>/' > tmp.txt
cat << EOF   > txt2xml.py
#!/usr/bin/python3
# Usage: python3 txt2xml.py xml_txt

import sys

xml_txt = sys.argv[1]

i = 0
with open(xml_txt, 'r') as f:
    line = f.readline()
    while line:
        if line == '$XML_HEADER':
                    i+=1
        with open('xml/' + str(int(i)) + '.xml', 'a') as g:
            print(line, end='', file=g)
        line = f.readline()
EOF
rm -f xml/*
python3 txt2xml.py tmp.txt; rm -f tmp.txt
page_num=$(ls -F xml/ | grep -v / | wc -l)
if [ -z "$PAGES" ]; then
        PAGES=`seq 1 $page_num`
fi


rm -f png/*
gm convert -density $DENSITY -geometry $GEOMETRY +adjoin $PDF_FILE png:png/%01d-tmp.png
for i in `seq 0 $(($page_num-1))`; do mv png/$i-tmp.png png/$(($i+1)).png; done


aws polly put-lexicon --name $LEXICON_NAME --content file://$LEXICON_FILE
for i in $PAGES;
do aws polly synthesize-speech \
       --lexicon-names $LEXICON_NAME \
       --text-type ssml \
       --output-format json \
       --voice-id $VOICE_ID \
       --speech-mark-types='["sentence"]' \
       --text file://xml/$i.xml \
       json/$i.json 2> tmp.txt;
   
   if [ -s tmp.txt ]; then
        echo "There is the following error in executing aws polly, with xml/$i.xml."
        cat tmp.txt; rm -f tmp.txt
        aws polly delete-lexicon --name $LEXICON_NAME
        exit
   fi
   
   aws polly synthesize-speech \
       --lexicon-names $LEXICON_NAME \
       --text-type ssml \
       --output-format mp3 \
       --voice-id $VOICE_ID \
       --text file://xml/$i.xml \
       mp3/$i.mp3;
done
rm -f tmp.txt
aws polly delete-lexicon --name $LEXICON_NAME


cat << EOF  > json2srt.py
#!/usr/bin/python3
# Usage: python3 json2srt.py polly_output.json srt_file.srt

import json
import os
import sys

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
		time_seconds2 = time_seconds1 + 1
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
EOF
for i in $PAGES; do python3 json2srt.py json/$i.json srt/$i.srt; done


for i in $PAGES; do ffmpeg -y -loop 1 -i png/$i.png -i mp3/$i.mp3 -r $FPS -vcodec libx264 -tune stillimage -pix_fmt yuv420p -shortest -vf "subtitles=srt/$i.srt:force_style='FontName=$FONT_NAME,FontSize=$FONT_SIZE'" mp4/$i.mp4; done


rm -f list.txt; for i in `seq 1 $page_num`; do echo "file mp4/$i.mp4" >> list.txt; done
ffmpeg -y -f concat -i list.txt -c copy $OUTPUT_MP4

