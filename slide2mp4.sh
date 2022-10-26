#!/bin/bash
# Usage: slide2mp4.sh [option] PDF_FILE TXT_FILE OUTPUT_MP4 ["page_num1 page_num2..."]
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
PPI="600"
SCALEX="1280"
SCALEY="720"
FONT_NAME="NotoSansCJKjp-Regular"
FONT_SIZE="14"
FPS="30"
FFMPEG_LOG_LEVEL="-loglevel error"
# Azure Speech (TTS) variables
AZURE_REGION="japaneast"
AZURE_TTS_VOICE_ID="ja-JP-NanamiNeural"
AZURE_TTS_VOICE_PITCH=0
AZURE_TTS_VOICE_STYLE="general"
AZURE_TTS_SUBS_KEY_FILENAME=~/.azure/tts-subs-keyfile
# Amazon Polly (TTS) variables
AWS_TTS_VOICE_ID="Mizuki"


# rm -rf json mp3 mp4 png srt xml


print_usage ()
{
	echo "Description:"
	echo "	$(basename $0) is a conversion tool, PDF slides to MP4 with audio and subtitles."
	echo "	$(basename $0) uses Azure Speech (default) or Amazon Polly, Text-to-Speech (TTS) service."
	echo "	$(basename $0) requires the following commands, ffmpeg, ffprobe, parallel, pdftocairo, python3, xmllint, aws polly (option), aws s3 (option)."
	echo "Usage:"
	echo "	$(basename $0) [option] PDF_FILE TXT_FILE OUTPUT_MP4 ["page_num1 page_num2..."]"
	echo "Options:"
	echo "	-h, --help			print this message."
	echo "	-geo, --geometry		specify the geometry of output mp4 files. (default geometry is \"1280x720\")"
	echo "	-npc, --no-pdf-convert		don't convert PDF to png."
	echo "	-ns, --no-subtitles		convert without subtitles."
	echo "	-lexicon                        specify lexicon file or url."
	echo "	-p, --path			specify the output directory. (default path is current directory)"
	echo "	-sp, --specific-pages		specify pages. (using all pages by default)"
	echo "	-j, --jobs			control of parallel jobs.
					(the default jobs option for parallel command is used, by default.)
					(e.g. \"--jobs 2\" subtracts 2 from the number of CPU threads.)"
	echo ""
	echo "	-azure				use Azure Speech (default)."
	echo "	-azure-region			specify Azure Region for using Azure Speech. (default Region is \"japaneast\")"
	echo "	-azure-vid, --azure-voice-id	specify Azure Speech voice name. (default voice name is \"ja-JP-NanamiNeural\")"
	echo "	-azure-style			specify Azure Speech voice style. (default voice style is \"general\")"
	echo "	-azure-pitch			specify Azure Speech voice pitch. (default voice pitch is \"0\", meaning 0%)"
	echo "	-azure-tts-key			specify subscription key file path for Azure Speech. (default file path is \"~/.azure/tts-subs-keyfile\")"
	echo ""
	echo "	-aws				use Amazon Polly."
	echo "	-aws-vid, --aws-voice-id	specify Amazon Polly voice ID. (default voice ID is \"Mizuki\", Japanese Female)"
	echo "	-aws-neural			use Amazon Polly Neural format, if possible."
	echo ""
	echo "Example1: The following command uses Azure Speech to create one mp4 file with audio and subtitles, named \"test-output.mp4\"." The subscription key to use Azure Speech must be found in \"~/azure/.tts-subs-keyfile\".
	echo "	$(basename $0) test-slides.pdf test-slides.txt test-output.mp4"
	echo ""
	echo "  When you specify the output directory, files created by slide2mp4 will be saved in the specified directory. If the directory does not exist, it will be created automatically."
	echo "	$(basename $0) -p ./outputs-directory test-slides.pdf test-slides.txt test-output.mp4"
	echo ""
	echo "Example2: The following command uses Azure Speech to create one mp4 file with audio and subtitles, named \"test-output.mp4\" using only specific pages, e.g. using only 1, 2 page."
	echo "	$(basename $0) -sp test-slides.pdf test-slides.txt test-output.mp4 \"1 2\""
	echo ""
	echo "Example3: If you have modified some of the slides, e.g. pages 1 and 3, you can apply the patch to \"test-output.mp4\" with the following command. When you run this command with Azure Speech \(not Amazon Polly\), \"test-lexicon.pls\" will be temporarily uploaded to Amazon S3."
	echo "	$(basename $0) -lexicon test-lexicon.pls test-slides.pdf test-slides.txt test-output.mp4 \"1 3\""
	echo ""
	echo "  When you don't use Amazon S3, you can specify public (non-private) URL for downloading the lexicon file."
	echo "	$(basename $0) -lexicon https://public_domain/test.pls test-slides.pdf test-slides.txt test-output.mp4 \"1 3\""
	echo ""
	echo "Example4: No subtitles option is also available, e.g. mp4 files on pages 1 and 3 are without subtitles."
	echo "	$(basename $0) -ns -lexicon test-lexicon.pls test-slides.pdf test-slides.txt test-output.mp4 \"1 3\""
	echo ""
	echo "Example5: No PDF converting option is also available, e.g. in the case of changing the talk script on pages 1 and 3."
	echo "	$(basename $0) -npc -ns -lexicon test-lexicon.pls test-slides.pdf test-slides.txt test-output.mp4 \"1 3\""
	echo ""
	echo "Example6: The following command specifies the geometry of output mp4 files (1080p), the Azure Region, voice name/pitch, subscription keyfile path to use Azure Speech."
	echo "	$(basename $0) -azure -geo 1920x1080 -azure-region centralus -azure-vid en-US-JennyNeural -azure-pitch -6 -azure-tts-key test-azure-keyfile test.pdf test.txt output.mp4"
	echo ""
	echo "Example7: The following command uses Amazon Polly to create one mp4 file with audio and subtitles, named \"test-output.mp4\"."
	echo "	$(basename $0) -aws test-slides.pdf test-slides.txt test-output.mp4"
	echo ""
	echo "Example8: Specify the Amazon Polly Neural format, voice ID, Matthew (Male, English, US). Note that the Neural format only works with some voice IDs."
	echo "	$(basename $0) -aws -aws-vid Matthew -aws-neural -lexicon lexicon.pls test.pdf test.txt output.mp4"
	echo ""
	exit
}


# Random String
RS=$(cat /dev/urandom |base64 2> /dev/null |tr -cd "a-z0-9" |fold -w 16 |head -n 1)


NS_FLAG=0; NO_CONVERT_FLAG=0;
AZURE_FLAG=1; AWS_FLAG=0
AWS_TTS_NEURAL_FLAG=0
LEXICON_FLAG=0
SLIDE2MP4_OUTPUTS_PATH="$(pwd)"
PARTIALLY_MODE=0
PARALLEL_JOBS_OPTION=""


i=0; arg_num=$#
while [ $# -gt 0 ]
do
	if [ "$1" == "-h" -o "$1" == "--help" ]; then
		print_usage
	elif [ "$1" == "-ns" -o "$1" == "--no-subtitles" ]; then
		NS_FLAG=1; shift
	elif [ "$1" == "-npc" -o "$1" == "--no-pdf-convert" ]; then
		NO_CONVERT_FLAG=1; shift
	elif [ "$1" == "-geo" -o "$1" == "--geometry" ]; then
		shift
		SCALEX=$(echo "$1"| awk -F '[x]' '{print $1}')
		SCALEY=$(echo "$1"| awk -F '[x]' '{print $2}')
		shift
	elif [ "$1" == "-lexicon" ]; then
		shift; LEXICON="$1"; LEXICON_FLAG=1; shift
	elif [ "$1" == "-p" -o "$1" == "--path" ]; then
		shift; SLIDE2MP4_OUTPUTS_PATH="$1"; shift
	elif [ "$1" == "-sp" -o "$1" == "--specific-pages" ]; then
		PARTIALLY_MODE=1; shift
	elif [ "$1" == "-j" -o "$1" == "--jobs" ]; then
		shift; PARALLEL_JOBS_OPTION="$1"; shift

	elif [ "$1" == "-azure" ]; then
		AZURE_FLAG=1; AWS_FLAG=0; shift; 
	elif [ "$1" == "-azure-region" ]; then
		shift; AZURE_REGION="$1"; shift
	elif [ "$1" == "-azure-vid" -o "$1" == "--azure-voice-id" ]; then
		shift; AZURE_TTS_VOICE_ID="$1"; shift
	elif [ "$1" == "-azure-style" ]; then
		shift; AZURE_TTS_VOICE_STYLE="$1"; shift
	elif [ "$1" == "-azure-pitch" ]; then
		shift; AZURE_TTS_VOICE_PITCH="$1"; shift
	elif [ "$1" == "-azure-tts-key" ]; then
		shift; AZURE_TTS_SUBS_KEY_FILENAME="$1"; shift

	elif [ "$1" == "-aws" ]; then
		AZURE_FLAG=0; AWS_FLAG=1; shift; 
	elif [ "$1" == "-aws-vid" -o "$1" == "--aws-voice-id" ]; then
		shift; AWS_TTS_VOICE_ID="$1"; shift
	elif [ "$1" == "-aws-neural" ]; then
		AWS_TTS_NEURAL_FLAG=1; shift

	else
		i=$(($i+1)); arg[i]="$1"; shift
	fi
done
PDF_FILE="${arg[1]}"
TXT_FILE="${arg[2]}"
OUTPUT_MP4="${arg[3]}"
PAGES="${arg[4]}"
SLIDE2MP4_DIR="$(cd "$(dirname "$0")"; pwd)"


if [ $arg_num -lt 3 ]; then
	echo "Too few arguments. Please check whether the number of arguments is 3 or more."
	echo "Please check '$(basename $0) -h' or '$(basename $0) --help'."
	exit
fi


mkdir -p "$SLIDE2MP4_OUTPUTS_PATH"
touch "$SLIDE2MP4_OUTPUTS_PATH"/testfile-$RS 2> /dev/null
if [ ! -e "$SLIDE2MP4_OUTPUTS_PATH"/testfile-$RS ]; then
	echo "You do not have permission to write to the $SLIDE2MP4_OUTPUTS_PATH ."
	exit
fi
rm -f "$SLIDE2MP4_OUTPUTS_PATH"/testfile-$RS


file "$PDF_FILE" > check_pdf_slide2mp4-$RS.txt
file "$TXT_FILE" > check_txt_slide2mp4-$RS.txt
CHECK_PDF=$(grep -i pdf check_pdf_slide2mp4-$RS.txt 2> /dev/null)
CHECK_TXT=$(grep -i text check_txt_slide2mp4-$RS.txt 2> /dev/null)
rm -f check_*_slide2mp4-$RS.txt
OUTPUT_MP4_NO_SPACE="$(echo -e "${OUTPUT_MP4}" |tr -d '[:space:]')"
if [ -z "$CHECK_PDF" ]; then
	echo "This "$PDF_FILE" is not PDF file. Please check PDF file."
	exit
elif [ -z "$CHECK_TXT" ]; then
	echo "This "$TXT_FILE" is not text file. Please check text file."
	exit
elif [ -z "$OUTPUT_MP4_NO_SPACE" ]; then
	echo "Please specify the name of the mp4 file to output."
	exit
elif [ ${OUTPUT_MP4_NO_SPACE##*.} != "mp4" ]; then
	echo "Please specify the name of the mp4 file to output."
	exit
fi


if [ $LEXICON_FLAG -eq 1 ]; then
	LEXICON_URL=""; LEXICON_FILE=tmp-lexicon-$RS.pls

	if [[ "$LEXICON" =~ https?://* ]]; then
		LEXICON_URL="$LEXICON"
		wget -q "$LEXICON_URL" -O $LEXICON_FILE

		if [ ! -s $LEXICON_FILE ]; then
			echo "Lexicon file is empty. Please make sure that the URL to download is corret, $LEXICON_URL."
			rm -f $LEXICON_FILE
			exit
		fi

	else
		cp -f "$LEXICON" $LEXICON_FILE 2> /dev/null
	fi

	xmllint "$LEXICON_FILE" 1> /dev/null 2> check_lexicon_error_slide2mp4-$RS.txt
	CHECK_XML=$(grep -i error check_lexicon_error_slide2mp4-$RS.txt)
	if [ -n "$CHECK_XML" ]; then
		echo "There is the following xml file parse error in "$LEXICON". Please check xml file."
		cat check_lexicon_error_slide2mp4-$RS.txt
		rm -f check_*_slide2mp4-$RS.txt $LEXICON_FILE
		exit
	fi
	rm -f check_*_slide2mp4-$RS.txt
fi


echo "Format checking of input files has been completed."


cp "$PDF_FILE" "$SLIDE2MP4_OUTPUTS_PATH"/PDF-$RS.pdf
cp "$TXT_FILE" "$SLIDE2MP4_OUTPUTS_PATH"/TXT-$RS.txt
mv $LEXICON_FILE "$SLIDE2MP4_OUTPUTS_PATH"/ 2> /dev/null
cd "$SLIDE2MP4_OUTPUTS_PATH"


mkdir -p json mp3 mp4 png srt xml


sed -e 's|^ *~~~TTS$|<?xml version="1.0" encoding="UTF-8"?>\n<speak version="1.1">|g' \
        -e 's|^ *~~~$|</speak>|g' TXT-$RS.txt |\
	awk '/<\?xml/,/<\/speak>/' |\
	sed -e 's|#.*||g' > tmp-$RS.txt
rm -f xml/* TXT-$RS.txt
python3 "$SLIDE2MP4_DIR"/lib/txt2xml.py tmp-$RS.txt; rm -f tmp-$RS.txt
page_num=$(ls -F xml/ | grep -v / | wc -l)
if [ -z "$PAGES" ]; then
        PAGES=`seq 1 $page_num`
fi


for i in $PAGES
do

	grep "^\s*~~~BREAK" xml/$i.xml |sed -e 's|~~~BREAK||' |sed -e 's|m||' |sed -e 's|s||' |awk '{print $1}' > tmp-$RS.txt
	if [ -s tmp-$RS.txt ]; then
		while read line
		do
			break_time=${line}
			sed -e "s|~~~BREAK "$break_time"s|\n\n<break time=\""$break_time"s\" />\n\n|" xml/$i.xml > tmp-$RS.xml
			mv tmp-$RS.xml xml/$i.xml
			sed -e "s|~~~BREAK "$break_time"ms|\n\n<break time=\""$break_time"ms\" />\n\n|" xml/$i.xml > tmp-$RS.xml
			mv tmp-$RS.xml xml/$i.xml
		done < tmp-$RS.txt
	fi

	grep "^\s*~~~SPEED" xml/$i.xml |sed -e 's|~~~SPEED||' |sed -e 's|x||' |awk '{print $1}' > tmp-$RS.txt
 	if [ -s tmp-$RS.txt ]; then
		speed_count=1

        	while read line
        	do
			speed_num=${line}; convert_speed_num=`echo "scale=3; $speed_num * 100" |bc |awk '{print int($1)}'`
			if [ $speed_count -eq 1 ]; then
				sed -e "s|~~~SPEED "$speed_num"x|<prosody rate=\"$convert_speed_num%\">|" xml/$i.xml > tmp-$RS.xml
				speed_count=2
			else
				sed -e "1,/~~~SPEED "$speed_num"x/ s|~~~SPEED "$speed_num"x|</prosody>\n<prosody rate=\"$convert_speed_num%\">|" xml/$i.xml > tmp-$RS.xml
			fi
			mv tmp-$RS.xml xml/$i.xml
        	done < tmp-$RS.txt

		sed -e 's|</speak>|</prosody>\n</speak>|g' xml/$i.xml > tmp-$RS.xml
		mv tmp-$RS.xml xml/$i.xml
	fi

	sed -i -e "s/&/&amp;/g" xml/$i.xml; rm -f xml/$i.xml-e

done
rm -f tmp-$RS.txt


if [ $NO_CONVERT_FLAG -eq 0 ]; then
	echo "The conversion from PDF to PNG starts now."
	rm -f png/*
	pdftocairo -png -r $PPI -scale-to-x $SCALEX -scale-to-y $SCALEY PDF-$RS.pdf png/image
	parallel --no-notice mv {1} {2} 2> /dev/null ::: png/image-0{1..99}.png :::+ png/image-{1..99}.png
	parallel --no-notice mv {1} {2} 2> /dev/null ::: png/image-00{1..9}.png :::+ png/image-{1..9}.png
	echo "The conversion from PDF to PNG has been successfully completed."
fi
rm -f PDF-$RS.pdf


if [ $AWS_FLAG -eq 1 ]; then

	LEXICON_OPTION=""

	if [ $LEXICON_FLAG -eq 1 ]; then
		LEXICON_NAME=$RS
		aws polly put-lexicon --name $LEXICON_NAME --content file://"$LEXICON_FILE" 2> tmp-$RS.txt

		if [ -s tmp-$RS.txt ]; then
			cat tmp-$RS.txt
			rm -f tmp-$RS.txt $LEXICON_FILE
			exit
		fi

		LEXICON_OPTION="--lexicon-names $LEXICON_NAME"
	fi

	ENGINE=""
	if [ $AWS_TTS_NEURAL_FLAG -eq 1 ]; then
		ENGINE="--engine neural"
	fi

	for i in $PAGES;

	do aws polly synthesize-speech $ENGINE $LEXICON_OPTION \
		--text-type ssml \
		--output-format mp3 \
		--voice-id $AWS_TTS_VOICE_ID \
		--text file://xml/$i.xml \
		mp3/$i.mp3 1> /dev/null 2> tmp-$RS.txt;

	if [ -s tmp-$RS.txt ]; then
		echo "There is the following error in executing aws polly, with xml/$i.xml."
		cat tmp-$RS.txt; rm -f tmp-$RS.txt $LEXICON_FILE
		if [ $LEXICON_FLAG -eq 1 ]; then
			aws polly delete-lexicon --name $LEXICON_NAME
		fi
		exit
	fi

	echo "mp3/$i.mp3 has been created."   

	if [ $NS_FLAG -eq 0 ]; then
		aws polly synthesize-speech $ENGINE $LEXICON_OPTION \
			--text-type ssml \
			--output-format json \
			--voice-id $AWS_TTS_VOICE_ID \
			--speech-mark-types='["sentence"]' \
			--text file://xml/$i.xml \
			json/$i.json &> /dev/null;
		sed -i -e "s/&amp;/\&/g" json/$i.json; rm -f json/$i.json-e
		echo "json/$i.json has been created."
	fi

	done
	rm -f tmp-$RS.txt $LEXICON_FILE
	if [ $LEXICON_FLAG -eq 1 ]; then
		aws polly delete-lexicon --name $LEXICON_NAME
	fi

elif [ $AZURE_FLAG -eq 1 ]; then

	if [ $LEXICON_FLAG -eq 1 ]; then
		AWS_S3_REGION=""; BUCKET_NAME=tmp-lexicon-$RS
		if [ "$LEXICON_URL" == "" ]; then
			AWS_S3_REGION="ap-northeast-1"
			aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_S3_REGION" --create-bucket-configuration LocationConstraint="$AWS_S3_REGION" 2> tmp-$RS.txt

			if [ -s tmp-$RS.txt ]; then
				cat tmp-$RS.txt
				rm -f tmp-$RS.txt transcripts-tmp-$RS.mp4 $LEXICON_FILE
				exit
			fi

			aws s3 cp "$LEXICON_FILE" s3://"$BUCKET_NAME"/ --acl public-read
			LEXICON_URL="https://"$BUCKET_NAME".s3."$AWS_S3_REGION".amazonaws.com/$LEXICON_FILE"
			rm -f tmp-$RS.txt
		fi
	else
		LEXICON_URL="https://dummy-$RS/dummy-$RS.pls"
	fi

	mkdir -p azure-xml; rm -f azure-xml/*
	mkdir -p azure-txt; rm -f azure-txt/*
	for i in $PAGES; do "$SLIDE2MP4_DIR"/lib/ssml-aws2azure.sh xml/$i.xml $i $AZURE_TTS_VOICE_ID $LEXICON_URL "$AZURE_TTS_VOICE_PITCH" $AZURE_TTS_VOICE_STYLE; done

	mkdir -p azure-mp3; rm -f azure-mp3/*
	for i in $PAGES;
	do 
		NUMS=$(ls azure-xml/$i-*.xml |wc -w |awk '{print $1}')
		AZURE_TTS_COMMAND="\"$SLIDE2MP4_DIR\"/lib/azure-tts.sh azure-xml/{1}-{2}.xml \"$AZURE_REGION\" \"$AZURE_TTS_SUBS_KEY_FILENAME\" azure-mp3/{1}-{2}.mp3"
		parallel --no-notice $AZURE_TTS_COMMAND ::: $i ::: `seq 1 $NUMS`

		for j in `seq 1 $NUMS`;
		do

			if [ ! -s azure-mp3/$i-$j.mp3 ]; then
				echo "azure-mp3/$i-$j.mp3 is empty file."
				echo "Please check xml/$i.xml, azure-xml/$i-$j.xml, Azure $AZURE_REGION Region, your Azure account settings, Azure Speech subscription key in $AZURE_TTS_SUBS_KEY_FILENAME."
				rm -f $LEXICON_FILE *-list-$RS.txt
				if [ $LEXICON_FLAG -eq 1 ]; then
					if [ ! $AWS_S3_REGION == "" ]; then
						aws s3api delete-object --bucket "$BUCKET_NAME" --key "$LEXICON_FILE"
						aws s3 rb s3://"$BUCKET_NAME"
					fi
				fi
				exit
			fi

			echo "file azure-mp3/$i-$j.mp3" >> $i-list-$RS.txt
		done
	done

	if [ $LEXICON_FLAG -eq 1 ]; then
		if [ ! $AWS_S3_REGION == "" ]; then
			aws s3api delete-object --bucket "$BUCKET_NAME" --key "$LEXICON_FILE"
			aws s3 rb s3://"$BUCKET_NAME"
		fi
	fi

	if [ $NS_FLAG -eq 0 ]; then

		for i in $PAGES;
		do
			time_value=0; time_info=0; rm -f json/$i.json
			NUMS=$(ls azure-xml/$i-*.xml |wc -w |awk '{print $1}')

			for j in `seq 1 $NUMS`;
			do
				seconds=$(ffprobe $FFMPEG_LOG_LEVEL -hide_banner -show_entries format=duration azure-mp3/$i-$j.mp3 |grep -i duration |sed -e 's/duration=//')
				mseconds=`echo "scale=4; $seconds * 1000" |bc`
				python3 "$SLIDE2MP4_DIR"/lib/repr.py azure-txt/$i-$j.txt tmp-$RS.txt
				awk '{print substr($0, 2, length($0)-2)}' tmp-$RS.txt |grep -v "<break time=\"" > value-$RS.txt
				awk '{print "{\"time\":'$time_info',\"value\":\"" $0}' value-$RS.txt |sed '$s/$/\"}/' >> json/$i.json
				time_value=`echo "scale=4; $time_value + $mseconds" |bc`
				time_info=${time_value%.*}
			done

			sed -i -e "s/&amp;/\&/g" json/$i.json; rm -f json/$i.json-e

			echo "json/$i.json has been created."

		done

	fi
	rm -f tmp-$RS.txt value-$RS.txt

	for i in $PAGES
	do
		ffmpeg $FFMPEG_LOG_LEVEL -y -f concat -i $i-list-$RS.txt -c copy mp3/$i.mp3
		echo "mp3/$i.mp3 has been created."
	done
	rm -rf *-list-$RS.txt $LEXICON_FILE azure-mp3 azure-txt azure-xml

fi


if [ $NS_FLAG -eq 0 ]; then
	for i in $PAGES;
	do
		python3 "$SLIDE2MP4_DIR"/lib/json2srt.py json/$i.json srt/$i.srt
		echo "srt/$i.srt has been created."
	done
fi


PAGES_LIST=$(echo $PAGES |xargs -n1)
if [ $NS_FLAG -eq 0 ]; then

	VF_OPTIONS="\"subtitles=srt/{}.srt:force_style='FontName=$FONT_NAME,FontSize=$FONT_SIZE'\""
	COMMAND_LIST="ffmpeg $FFMPEG_LOG_LEVEL -y -loop 1 -i png/image-{}.png -i mp3/{}.mp3 -r $FPS -vcodec libx264 -tune stillimage -pix_fmt yuv420p -shortest -vf $VF_OPTIONS mp4/{}.mp4; echo \"mp4/{}.mp4 has been created.\""

	if [ ! $PARALLEL_JOBS_OPTION == "" ]; then
		parallel --no-notice --jobs "$PARALLEL_JOBS_OPTION" $COMMAND_LIST ::: $PAGES_LIST
	else
		parallel --no-notice $COMMAND_LIST ::: $PAGES_LIST
	fi

else

	COMMAND_LIST="ffmpeg $FFMPEG_LOG_LEVEL -y -loop 1 -i png/image-{}.png -i mp3/{}.mp3 -r $FPS -vcodec libx264 -tune stillimage -pix_fmt yuv420p -shortest mp4/{}.mp4; echo \"mp4/{}.mp4 has been created.\""

	if [ ! $PARALLEL_JOBS_OPTION == "" ]; then
		parallel --no-notice --jobs "$PARALLEL_JOBS_OPTION" $COMMAND_LIST ::: $PAGES_LIST
	else
		parallel --no-notice $COMMAND_LIST ::: $PAGES_LIST
	fi

fi


for i in $PAGES
do
	if [ ! -s mp4/$i.mp4 ]; then
		echo; echo
		echo "mp4/$i.mp4 is empty file. FFmpeg job for creating mp4/$i.mp4 has been failed. Please check your pdf or talk script file."
		exit
	fi
done


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


echo; echo "Combining mp4 files..."
ffmpeg $FFMPEG_LOG_LEVEL -y -f concat -i list-$RS.txt -async 1 "$OUTPUT_MP4"
rm -f list-$RS.txt
echo "Combining mp4 files has been completed."


echo
echo "The conversion from PDF slides to mp4 files has been successfully completed."
echo "Please check $SLIDE2MP4_OUTPUTS_PATH/$OUTPUT_MP4."

