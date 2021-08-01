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


DENSITY="600"
GEOMETRY="1280x760"
LEXICON_NAME="test"
VOICE_ID="Mizuki"
FONT_NAME="NotoSansCJKjp-Regular"
FONT_SIZE="14"
FPS="25"


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
	echo "	-h, --help				print this message."
	echo "	-le, --ffmpeg-loglevel-error		ffmpeg loglevel is error. (default level is info)"
	echo "	-npc, --no-pdf-convert			don't convert PDF to png."
	echo "	-ns, --no-subtitles			convert without subtitles."
	echo ""
	echo "Example1: The following command creates one mp4 file with audio and subtitles, named \"test-output.mp4\"."
	echo "	$(basename $0) test-slides.pdf test-slides.txt test-lexicon.pls test-output.mp4"
	echo ""
	echo "Example2: If you have modified some of the slides, e.g. pages 2 and 3, you can apply the patch to \"test-output.mp4\" with the following command."
	echo "	$(basename $0) test-slides.pdf test-slides.txt test-lexicon.pls test-output.mp4 \"2 3\""
	echo ""
	echo "Example3: No subtitles option is also available, e.g. mp4 files on pages 1 and 3 are without subtitles."
	echo "	$(basename $0) -ns test-slides.pdf test-slides.txt test-lexicon.pls test-output.mp4 \"1 3\""
	echo ""
	echo "Example4: No PDF converting option is also available, e.g. in the case of changing the talk script on pages 1 and 3."
	echo "	$(basename $0) -npc -ns test-slides.pdf test-slides.txt test-lexicon.pls test-output.mp4 \"1 3\""
	exit
}


NS_FLAG=0; NO_CONVERT_FLAG=0
FFMPEG_LOG_LEVEL="-loglevel info"
i=0; arg_num=$#
while [ $# -gt 0 ]
do
	if [ "$1" == "-h" -o "$1" == "--help" ]; then
		print_usage
	elif [ "$1" == "-ns" -o "$1" == "--no-subtitles" ]; then
		NS_FLAG=1; shift
	elif [ "$1" == "-npc" -o "$1" == "--no-pdf-convert" ]; then
		NO_CONVERT_FLAG=1; shift
	elif [ "$1" == "-le" -o "$1" == "--ffmpeg-loglevel-error" ]; then
		FFMPEG_LOG_LEVEL="-loglevel error"; shift
	else
		i=$(($i+1)); arg[i]="$1"; shift
	fi
done
PDF_FILE="${arg[1]}"
TXT_FILE="${arg[2]}"
LEXICON_FILE="${arg[3]}"
OUTPUT_MP4="${arg[4]}"
PAGES="${arg[5]}"
SLIDE2MP4_DIR="$(cd "$(dirname "$0")"; pwd)"


if [ $arg_num -lt 4  -o  $arg_num -gt 8 ]; then
	echo "Too few or many arguments. Please check whether the number of arguments is between 4 and 8."
	echo "Please check '$(basename $0) -h' or '$(basename $0) --help'."
	exit
fi


file "$PDF_FILE" > check_pdf_slide2mp4.txt
file "$TXT_FILE" > check_txt_slide2mp4.txt
xmllint "$LEXICON_FILE" 1> /dev/null 2> check_lexicon_error_slide2mp4.txt
CHECK_PDF=$(grep -i pdf check_pdf_slide2mp4.txt 2> /dev/null)
CHECK_TXT=$(grep -i text check_txt_slide2mp4.txt 2> /dev/null)
CHECK_XML=$(grep -i error check_lexicon_error_slide2mp4.txt)
rm -f check_*_slide2mp4.txt
OUTPUT_MP4_NO_SPACE="$(echo -e "${OUTPUT_MP4}" |tr -d '[:space:]')"
if [ -z "$CHECK_PDF" ]; then
	echo "This is not PDF file. Please check PDF file."
	exit
elif [ -z "$CHECK_TXT" ]; then
	echo "This is not text file. Please check text file."
	exit
elif [ -n "$CHECK_XML" ]; then
	echo "XML file parse error. Please check xml file."
	exit
elif [ -z "$OUTPUT_MP4_NO_SPACE" ]; then
	echo "Please specify the name of the mp4 file to output."
	exit
elif [ ${OUTPUT_MP4_NO_SPACE##*.} != "mp4" ]; then
	echo "Please specify the name of the mp4 file to output."
	exit
fi
echo "Format checking of input files has been completed."


mkdir -p json mp3 mp4 png srt xml


cat "$TXT_FILE" |awk '/<\?xml/,/<\/speak>/' > tmp.txt
rm -f xml/*
python3 "$SLIDE2MP4_DIR"/lib/txt2xml.py tmp.txt; rm -f tmp.txt
page_num=$(ls -F xml/ | grep -v / | wc -l)
if [ -z "$PAGES" ]; then
        PAGES=`seq 1 $page_num`
fi


if [ $NO_CONVERT_FLAG -eq 0 ]; then
	echo "The conversion from PDF to PNG starts now."
	rm -f png/*
	gm convert -density $DENSITY -geometry $GEOMETRY +adjoin "$PDF_FILE" png:png/%01d-tmp.png
	for i in `seq 0 $(($page_num-1))`; do mv png/$i-tmp.png png/$(($i+1)).png; done
	echo "The conversion from PDF to PNG has been successfully completed."
fi


aws polly put-lexicon --name $LEXICON_NAME --content file://"$LEXICON_FILE"
for i in $PAGES;
do aws polly synthesize-speech \
       --lexicon-names $LEXICON_NAME \
       --text-type ssml \
       --output-format mp3 \
       --voice-id $VOICE_ID \
       --text file://xml/$i.xml \
       mp3/$i.mp3 1> /dev/null 2> tmp.txt;
   
   if [ -s tmp.txt ]; then
        echo "There is the following error in executing aws polly, with xml/$i.xml."
        cat tmp.txt; rm -f tmp.txt
        aws polly delete-lexicon --name $LEXICON_NAME
        exit
   fi

   echo "mp3/$i.mp3 has been created."   

   if [ $NS_FLAG -eq 0 ]; then
   	aws polly synthesize-speech \
            --lexicon-names $LEXICON_NAME \
            --text-type ssml \
            --output-format json \
            --voice-id $VOICE_ID \
            --speech-mark-types='["sentence"]' \
            --text file://xml/$i.xml \
            json/$i.json &> /dev/null;
	echo "json/$i.json has been created."
   fi
done
rm -f tmp.txt
aws polly delete-lexicon --name $LEXICON_NAME


if [ $NS_FLAG -eq 0 ]; then
	for i in $PAGES;
	do
		python3 "$SLIDE2MP4_DIR"/lib/json2srt.py json/$i.json srt/$i.srt
		echo "srt/$i.srt has been created."
	done
fi


for i in $PAGES
do
	if [ $NS_FLAG -eq 0 ]; then
		ffmpeg $FFMPEG_LOG_LEVEL -y -loop 1 -i png/$i.png -i mp3/$i.mp3 -r $FPS -vcodec libx264 -tune stillimage -pix_fmt yuv420p -shortest -vf "subtitles=srt/$i.srt:force_style='FontName=$FONT_NAME,FontSize=$FONT_SIZE'" mp4/$i.mp4
	else
		ffmpeg $FFMPEG_LOG_LEVEL -y -loop 1 -i png/$i.png -i mp3/$i.mp3 -r $FPS -vcodec libx264 -tune stillimage -pix_fmt yuv420p -shortest mp4/$i.mp4
	fi

	if [ ! -s mp4/$i.mp4 ]; then
		echo; echo
		echo "FFmpeg job for creating mp4/$i.mp4 has been failed. Please check your pdf or talk script file."
		exit
	fi

	if [ "$FFMPEG_LOG_LEVEL" == "-loglevel info" ]; then
		echo; echo
	fi
	echo "mp4/$i.mp4 has been created."
done


PARTIALLY_MODE=0
for i in `seq 1 $page_num`
do
	if [ ! -s "mp4/$i.mp4" ]; then
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


ffmpeg $FFMPEG_LOG_LEVEL -y -f concat -i list.txt -c copy "$OUTPUT_MP4"
rm -rf list.txt xml


echo; echo
echo "The conversion from PDF slides to mp4 files has been successfully completed."
echo "Please check $OUTPUT_MP4."

