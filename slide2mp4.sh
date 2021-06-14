#!/bin/bash
# Usage: slide2mp4.sh [option] PDF_FILE TXT_FILE LEXICON_FILE OUTPUT_MP4 ["page_num1 page_num2..."]
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


XML_HEADER="<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
DENSITY="600"
GEOMETRY="1280x720"
LEXICON_NAME="test"
VOICE_ID="Mizuki"
FONT_NAME="NotoSansCJKjp-Regular"
FONT_SIZE="14"
FPS="25"
SUBTITLES_INTERVAL_SECONDS="1"


# rm -rf json mp3 mp4 png srt xml


print_usage ()
{
	echo "Description:"
	echo "	$(basename $0) is a conversion tool, PDF slides to MP4 with audio and subtitles."
	echo "	$(basename $0) uses Amazon Polly, Text-to-Speech (TTS) service."
	echo "	$(basename $0) requires the following commands, aws polly, ffmpeg, gm convert, python3, xmllint."
	echo "Usage:"
	echo "	$(basename $0) [option] PDF_FILE TXT_FILE LEXICON_FILE OUTPUT_MP4 ["page_num1 page_num2..."]"
	echo "Options:"
	echo "	-h, --help		print this message."
	echo "	-ns, --no-subtitles	convert without subtitles."
	echo ""
	echo "Example1: The following command creates one mp4 file with audio and subtitles, named \"test-output.mp4\"."
	echo "	$(basename $0) test-slides.pdf test-slides.txt test-lexicon.pls test-output.mp4"
	echo ""
	echo "Example2: If you have modified some of the slides, e.g. pages 2 and 3, you can apply the patch to \"test-output.mp4\" with the following command."
	echo "	$(basename $0) test-slides.pdf test-slides.txt test-lexicon.pls test-output.mp4 \"2 3\""
	echo ""
	echo "Example3: No subtitles option is also available, e.g. mp4 files on pages 1 and 3 are without subtitles."
	echo "	$(basename $0) -ns test-slides.pdf test-slides.txt test-lexicon.pls test-output.mp4 \"1 3\""
	exit
}


cat_json2srt_py ()
{

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
		time_seconds2 = time_seconds1 + $SUBTITLES_INTERVAL_SECONDS
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

}


if [ $# -ne 0 ]; then
	if [ "$1" == "-h" -o "$1" == "--help" ]; then
		print_usage
	fi
fi
if [ $# -ne 4 -a $# -ne 5 -a $# -ne 6 ]; then
	echo "Too few or many arguments. Please check whether the number of arguments is 4 or 5 or 6."
	echo "Please check '$(basename $0) -h' or '$(basename $0) --help'."
	exit
fi


NS_FLAG=0; CONVERT_FLAG=1; i=0
while [ $# -gt 0 ]
do
	if [ "$1" == "-ns" -o "$1" == "--no-subtitles" ]; then
		NS_FLAG=1; shift
	fi
	if [ "$1" == "-npc" -o "$1" == "--no-pdf-convert" ]; then
		CONVERT_FLAG=0; shift
	fi
	i=$(($i+1)); arg[i]="$1"; shift
done
PDF_FILE="${arg[1]}"
TXT_FILE="${arg[2]}"
LEXICON_FILE="${arg[3]}"
OUTPUT_MP4="${arg[4]}"
PAGES="${arg[5]}"


file "$PDF_FILE" > check_pdf_slide2mp4.txt
file "$TXT_FILE" > check_txt_slide2mp4.txt
xmllint "$LEXICON_FILE" 1> /dev/null 2> check_lexicon_error_slide2mp4.txt
CHECK_PDF=$(grep -i pdf check_pdf_slide2mp4.txt 2> /dev/null)
CHECK_TXT=$(grep -i text check_txt_slide2mp4.txt 2> /dev/null)
CHECK_XML=$(grep -i error check_lexicon_error_slide2mp4.txt)
rm -f check_*_slide2mp4.txt
if [ -z "$CHECK_PDF" ]; then
	echo "This is not PDF file. Please check PDF file."
	exit
elif [ -z "$CHECK_TXT" ]; then
	echo "This is not text file. Please check text file."
	exit
elif [ -n "$CHECK_XML" ]; then
	echo "XML file parse error. Please check xml file."
	exit
elif [ -z "$OUTPUT_MP4" ]; then
	echo "Please specify the name of the mp4 file to output."
	exit
elif [ ${OUTPUT_MP4##*.} != "mp4" ]; then
	echo "Please specify the name of the mp4 file to output."
	exit
fi
echo "Format checking of input files is completed."


mkdir -p json mp3 mp4 png srt xml


cat "$TXT_FILE" |awk '/<\?xml/,/<\/speak>/' > tmp.txt
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


if [ $CONVERT_FLAG -eq 1 ]; then
	rm -f png/*
	gm convert -density $DENSITY -geometry $GEOMETRY +adjoin "$PDF_FILE" png:png/%01d-tmp.png
	for i in `seq 0 $(($page_num-1))`; do mv png/$i-tmp.png png/$(($i+1)).png; done
fi


aws polly put-lexicon --name $LEXICON_NAME --content file://"$LEXICON_FILE"
for i in $PAGES;
do aws polly synthesize-speech \
       --lexicon-names $LEXICON_NAME \
       --text-type ssml \
       --output-format mp3 \
       --voice-id $VOICE_ID \
       --text file://xml/$i.xml \
       mp3/$i.mp3 2> tmp.txt;
   
   if [ -s tmp.txt ]; then
        echo "There is the following error in executing aws polly, with xml/$i.xml."
        cat tmp.txt; rm -f tmp.txt
        aws polly delete-lexicon --name $LEXICON_NAME
        exit
   fi
   
   if [ $NS_FLAG -eq 0 ]; then
   	aws polly synthesize-speech \
            --lexicon-names $LEXICON_NAME \
            --text-type ssml \
            --output-format json \
            --voice-id $VOICE_ID \
            --speech-mark-types='["sentence"]' \
            --text file://xml/$i.xml \
            json/$i.json;
   fi
done
rm -f tmp.txt
aws polly delete-lexicon --name $LEXICON_NAME


if [ $NS_FLAG -eq 0 ]; then
	cat_json2srt_py
	for i in $PAGES; do python3 json2srt.py json/$i.json srt/$i.srt; done
fi


if [ $NS_FLAG -eq 0 ]; then
	for i in $PAGES; do ffmpeg -y -loop 1 -i png/$i.png -i mp3/$i.mp3 -r $FPS -vcodec libx264 -tune stillimage -pix_fmt yuv420p -shortest -vf "subtitles=srt/$i.srt:force_style='FontName=$FONT_NAME,FontSize=$FONT_SIZE'" mp4/$i.mp4; done
else
	for i in $PAGES; do ffmpeg -y -loop 1 -i png/$i.png -i mp3/$i.mp3 -r $FPS -vcodec libx264 -tune stillimage -pix_fmt yuv420p -shortest mp4/$i.mp4; done
fi


PARTIALLY_MODE=0
for i in `seq 1 $page_num`
do
	if [ ! -e "mp4/$i.mp4" ]; then
		PARTIALLY_MODE=1
		break
	fi
done
rm -f list.txt
if [ $PARTIALLY_MODE -eq 0 ]; then
	for i in `seq 1 $page_num`; do echo "file mp4/$i.mp4" >> list.txt; done
else
	for i in $PAGES; do echo "file mp4/$i.mp4" >> list.txt; done
fi


ffmpeg -y -f concat -i list.txt -c copy "$OUTPUT_MP4"


rm -f json2srt.py list.txt txt2xml.py
rm -rf json xml

