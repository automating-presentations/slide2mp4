#!/bin/bash
# Usage: slide2mp4.sh [option] PDF_FILE TXT_FILE LEXICON_FILE/URL OUTPUT_MP4 ["page_num1 page_num2..."]
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


# The following variables are to be modified by the user as appropriate.
DENSITY="600"
GEOMETRY="1280x720"
VOICE_ID="Mizuki"
FONT_NAME="NotoSansCJKjp-Regular"
FONT_SIZE="14"
FPS="25"
# Azure TTS variables
AZURE_REGION="japaneast"
AZURE_TTS_VOICE_ID="ja-JP-NanamiNeural"
AZURE_TTS_SUBS_KEY_FILENAME=~/.azure/tts-subs-keyfile


# rm -rf json mp3 mp4 png srt xml


print_usage ()
{
	echo "Description:"
	echo "	$(basename $0) is a conversion tool, PDF slides to MP4 with audio and subtitles."
	echo "	$(basename $0) uses Amazon Polly (default) or Azure Speech, Text-to-Speech (TTS) service."
	echo "	$(basename $0) requires the following commands, aws polly, aws s3, ffmpeg, ffprobe, gm convert, python3, xmllint."
	echo "Usage:"
	echo "	$(basename $0) [option] PDF_FILE TXT_FILE LEXICON_FILE/URL OUTPUT_MP4 ["page_num1 page_num2..."]"
	echo "Options:"
	echo "	-h, --help			print this message."
	echo "	-geo, --geometry		specify the geometry of output mp4 files. (default geometry is \"1280x720\")"
	echo "	-le, --ffmpeg-loglevel-error	ffmpeg loglevel is \"error\". (default level is \"info\")"
	echo "	-neural				use Amazon Polly Neural format, if possible."
	echo "	-npc, --no-pdf-convert		don't convert PDF to png."
	echo "	-ns, --no-subtitles		convert without subtitles."
	echo "	-vid, --voice-id		specify Amazon Polly voice ID. (default voice ID is \"Mizuki\", Japanese Female)"
	echo "	-azure				use Azure Speech."
	echo "	-azure-region			specify Azure Region for using Azure Speech. (default Region is \"japaneast\")"
	echo "	-azure-vid, --azure-voice-id	specify Azure Speech voice name. (default voice name is \"ja-JP-NanamiNeural\")"
	echo "	-azure-tts-key			specify subscription key file path for Azure Speech. (default file path is \"~/.azure/tts-subs-keyfile\")"
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
	echo ""
	echo "Example5: Specify the Neural format, the geometry of output mp4 files (1080p) and Amazon Polly voice ID, Matthew (Male, English, US). Note that the Neural format only works with some voice IDs."
	echo "	$(basename $0) -geo 1920x1080 -vid Matthew -neural test.pdf test.txt lexicon.pls output.mp4"
	echo ""
	echo "Example6: The following command specifies the use of Azure Speech. The subscription key to use Azure Speech must be found in \"~/azure/.tts-subs-keyfile\". When you run this command, \"test-lexicon.pls\" will be temporarily uploaded to Amazon S3."
	echo "	$(basename $0) -azure test-slides.pdf test-slides.txt test-lexicon.pls test-output.mp4"
	echo ""
	echo "Example7: The following command specifies the Azure Region, voice name, subscription keyfile path to use Azure Speech. When using Azure Speech, you can specify public (non-private) URL where you can refer to \"test.pls\"."
	echo "	$(basename $0) -azure -azure-region centralus -azure-vid en-US-JennyNeural -azure-tts-key test-azure-keyfile test.pdf test.txt http://publicdomain/test.pls output.mp4"
	exit
}


# Random String
RS=$(cat /dev/urandom |base64 |tr -cd "a-z0-9" |fold -w 16 |head -n 1)


NS_FLAG=0; NO_CONVERT_FLAG=0; NEURAL_FLAG=0
AWS_FLAG=1; AZURE_FLAG=0
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
	elif [ "$1" == "-geo" -o "$1" == "--geometry" ]; then
		shift; GEOMETRY="$1"; shift
	elif [ "$1" == "-vid" -o "$1" == "--voice-id" ]; then
		shift; VOICE_ID="$1"; shift
	elif [ "$1" == "-neural" ]; then
		NEURAL_FLAG=1; shift
	elif [ "$1" == "-azure" ]; then
		AWS_FLAG=0; AZURE_FLAG=1; shift; 
	elif [ "$1" == "-azure-region" ]; then
		shift; AZURE_REGION="$1"; shift
	elif [ "$1" == "-azure-vid" -o "$1" == "--azure-voice-id" ]; then
		shift; AZURE_TTS_VOICE_ID="$1"; shift
	elif [ "$1" == "-azure-tts-key" ]; then
		shift; AZURE_TTS_SUBS_KEY_FILENAME="$1"; shift
	else
		i=$(($i+1)); arg[i]="$1"; shift
	fi
done
PDF_FILE="${arg[1]}"
TXT_FILE="${arg[2]}"
LEXICON="${arg[3]}"
OUTPUT_MP4="${arg[4]}"
PAGES="${arg[5]}"
SLIDE2MP4_DIR="$(cd "$(dirname "$0")"; pwd)"


if [ $arg_num -lt 4 ]; then
	echo "Too few arguments. Please check whether the number of arguments is 4 or more."
	echo "Please check '$(basename $0) -h' or '$(basename $0) --help'."
	exit
fi


LEXICON_URL=""; LEXICON_FILE="$LEXICON"
if [ $AWS_FLAG -eq 1 ]; then

	if [[ "$LEXICON" =~ https?://* ]]; then
		LEXICON_FILE=tmp-lexicon-$RS.pls
		LEXICON_URL="$LEXICON"
		wget -q "$LEXICON_URL" -O $LEXICON_FILE

		if [ ! -s $LEXICON_FILE ]; then
			echo "Lexicon file is empty. Please make sure that the URL to download is corret, $LEXICON_URL."
			rm -f tmp-lexicon-$RS.pls
			exit
		fi

	fi

elif [ $AZURE_FLAG -eq 1 ]; then

	if [[ "$LEXICON" =~ https?://* ]]; then
		LEXICON_URL="$LEXICON"
	fi

fi


file "$PDF_FILE" > check_pdf_slide2mp4-$RS.txt
file "$TXT_FILE" > check_txt_slide2mp4-$RS.txt
xmllint "$LEXICON_FILE" 1> /dev/null 2> check_lexicon_error_slide2mp4-$RS.txt
CHECK_PDF=$(grep -i pdf check_pdf_slide2mp4-$RS.txt 2> /dev/null)
CHECK_TXT=$(grep -i text check_txt_slide2mp4-$RS.txt 2> /dev/null)
CHECK_XML=$(grep -i error check_lexicon_error_slide2mp4-$RS.txt)
rm -f check_*_slide2mp4-$RS.txt
OUTPUT_MP4_NO_SPACE="$(echo -e "${OUTPUT_MP4}" |tr -d '[:space:]')"
if [ -z "$CHECK_PDF" ]; then
	echo "This "$PDF_FILE" is not PDF file. Please check PDF file."
	exit
elif [ -z "$CHECK_TXT" ]; then
	echo "This "$TXT_FILE" is not text file. Please check text file."
	exit
elif [ -n "$CHECK_XML" ]; then
	echo "There is xml file parse error in "$LEXICON_FILE". Please check xml file."
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


cat "$TXT_FILE" |awk '/<\?xml/,/<\/speak>/' > tmp-$RS.txt
rm -f xml/*
python3 "$SLIDE2MP4_DIR"/lib/txt2xml.py tmp-$RS.txt; rm -f tmp-$RS.txt
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


if [ $AWS_FLAG -eq 1 ]; then

	LEXICON_NAME=$RS
	aws polly put-lexicon --name $LEXICON_NAME --content file://"$LEXICON_FILE" 2> tmp-$RS.txt

	if [ -s tmp-$RS.txt ]; then
		cat tmp-$RS.txt
		rm -f tmp-$RS.txt tmp-lexicon-$RS.pls
		exit
	fi

	ENGINE=""
	if [ $NEURAL_FLAG -eq 1 ]; then
		ENGINE="--engine neural"
	fi

	for i in $PAGES;

	do aws polly synthesize-speech $ENGINE \
		--lexicon-names $LEXICON_NAME \
		--text-type ssml \
		--output-format mp3 \
		--voice-id $VOICE_ID \
		--text file://xml/$i.xml \
		mp3/$i.mp3 1> /dev/null 2> tmp-$RS.txt;

	if [ -s tmp-$RS.txt ]; then
		echo "There is the following error in executing aws polly, with xml/$i.xml."
		cat tmp-$RS.txt; rm -f tmp-$RS.txt
		aws polly delete-lexicon --name $LEXICON_NAME
		rm -f tmp-lexicon-$RS.pls
		exit
	fi

	echo "mp3/$i.mp3 has been created."   

	if [ $NS_FLAG -eq 0 ]; then
		aws polly synthesize-speech $ENGINE \
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
	rm -f tmp-$RS.txt tmp-lexicon-$RS.pls
	aws polly delete-lexicon --name $LEXICON_NAME

elif [ $AZURE_FLAG -eq 1 ]; then

	AWS_S3_REGION=""; BUCKET_NAME=tmp-lexicon-$RS
	if [ "$LEXICON_URL" == "" ]; then
		AWS_S3_REGION="ap-northeast-1"
		aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_S3_REGION" --create-bucket-configuration LocationConstraint="$AWS_S3_REGION" 2> tmp-$RS.txt

		if [ -s tmp-$RS.txt ]; then
			cat tmp-$RS.txt
			rm -f tmp-$RS.txt transcripts-tmp-$RS.mp4
			exit
		fi

		aws s3 cp "$LEXICON_FILE" s3://"$BUCKET_NAME"/ --acl public-read
		LEXICON_URL="https://"$BUCKET_NAME".s3."$AWS_S3_REGION".amazonaws.com/$LEXICON_FILE"
		rm -f tmp-$RS.txt
	fi

	mkdir -p azure-xml; rm -f azure-xml/*
	mkdir -p azure-txt; rm -f azure-txt/*
	for i in $PAGES; do "$SLIDE2MP4_DIR"/lib/ssml-aws2azure.sh xml/$i.xml $i $AZURE_TTS_VOICE_ID $LEXICON_URL; done

	mkdir -p azure-mp3; rm -f azure-mp3/*
	for i in $PAGES;
	do 
		NUMS=$(ls azure-xml/$i-*.xml |wc -w |awk '{print $1}')
		for j in `seq 1 $NUMS`;
		do
			"$SLIDE2MP4_DIR"/lib/azure-tts.sh azure-xml/$i-$j.xml "$AZURE_REGION" "$AZURE_TTS_SUBS_KEY_FILENAME" azure-mp3/$i-$j.mp3

			if [ ! -s azure-mp3/$i-$j.mp3 ]; then
				echo "azure-mp3/$i-$j.mp3 is empty file."
				echo "Please check azure-xml/$i-$j.xml, Azure $AZURE_REGION Region, $AZURE_TTS_SUBS_KEY_FILENAME."
				rm -f tmp-lexicon-$RS.pls
				if [ ! $AWS_S3_REGION == "" ]; then
					aws s3api delete-object --bucket "$BUCKET_NAME" --key "$LEXICON_FILE"
					aws s3 rb s3://"$BUCKET_NAME"
				fi
				exit
			fi

			echo "file azure-mp3/$i-$j.mp3" >> $i-list-$RS.txt
		done
	done

	if [ ! $AWS_S3_REGION == "" ]; then
		aws s3api delete-object --bucket "$BUCKET_NAME" --key "$LEXICON_FILE"
		aws s3 rb s3://"$BUCKET_NAME"
	fi

	if [ $NS_FLAG -eq 0 ]; then

		for i in $PAGES;
		do
			time_value=0; time_info=0; rm -f json/$i.json
			NUMS=$(ls azure-xml/$i-*.xml |wc -w |awk '{print $1}')

			for j in `seq 1 $NUMS`;
			do
				seconds=$(ffprobe -loglevel error -hide_banner -show_entries format=duration azure-mp3/$i-$j.mp3 |grep -i duration |sed -e 's/duration=//')
				mseconds=`echo "scale=4; $seconds * 1000" |bc`
				python3 "$SLIDE2MP4_DIR"/lib/repr.py azure-txt/$i-$j.txt tmp-$RS.txt
				awk '{print substr($0, 2, length($0)-2)}' tmp-$RS.txt > value-$RS.txt
				awk '{print "{\"time\":'$time_info',\"value\":\"" $0}' value-$RS.txt |sed '$s/$/\"}/' >> json/$i.json
				time_value=`echo "scale=4; $time_value + $mseconds" |bc`
				time_info=${time_value%.*}
			done

			echo "json/$i.json has been created."

		done

	fi
	rm -f tmp-$RS.txt value-$RS.txt

	for i in $PAGES
	do
		ffmpeg $FFMPEG_LOG_LEVEL -y -f concat -i $i-list-$RS.txt -c copy mp3/$i.mp3
		echo "mp3/$i.mp3 has been created."
	done
	rm -rf *-list-$RS.txt tmp-lexicon-$RS.pls azure-mp3 azure-txt azure-xml

fi


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
rm -f list-$RS.txt
if [ $PARTIALLY_MODE -eq 0 ]; then
	for i in `seq 1 $page_num`; do echo "file mp4/$i.mp4" >> list-$RS.txt; done
else
	for i in $PAGES; do echo "file mp4/$i.mp4" >> list-$RS.txt; done
fi


ffmpeg $FFMPEG_LOG_LEVEL -y -f concat -i list-$RS.txt -c copy "$OUTPUT_MP4"
rm -rf list-$RS.txt xml


echo; echo
echo "The conversion from PDF slides to mp4 files has been successfully completed."
echo "Please check $OUTPUT_MP4."

