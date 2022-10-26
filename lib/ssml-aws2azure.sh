#!/bin/bash
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


AWS_SSML_XML="$1"
PAGE_NUMBER="$2"
VOICE_NAME="$3"
#LEXICON_URL="https://raw.githubusercontent.com/automating-presentations/slide2mp4/main/test/test-lexicon.pls"
LEXICON_URL="$4"
PITCH="$5"
STYLE="$6"


# Random String
RS=$(cat /dev/urandom |base64 2> /dev/null |tr -cd "a-z0-9" |fold -w 16 |head -n 1)
SPLIT="sentence-split-$(cat /dev/urandom |base64 2> /dev/null |tr -cd "a-z0-9" |fold -w 16 |head -n 1)"


XML_VER="<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
SPEAK_VER="<speak xmlns=\"http://www.w3.org/2001/10/synthesis\" xmlns:mstts=\"http://www.w3.org/2001/mstts\" xmlns:emo=\"http://www.w3.org/2009/10/emotionml\" version=\"1.0\" xml:lang=\"en-US\">"
VOICE="<voice name=\"$VOICE_NAME\"><mstts:express-as style=\"$STYLE\" >"
LEXICON_URI="<lexicon uri=\"$LEXICON_URL\"/>"


cp "$AWS_SSML_XML" tmp-aws-$RS.xml
grep "<prosody\ *rate" tmp-aws-$RS.xml |sed -e "s/<prosody rate=\"//" -e "s/%\">//" | \
	awk '{print $1}' |awk '!dicline[$0]++' > tmp-$RS.txt
if [ -s tmp-$RS.txt ]; then
	while read line
        do
		rate_num=${line}; convert_rate_num=$(($rate_num-100))
		sed -e "s/<prosody rate=\"$rate_num%\">/<prosody rate=\"$convert_rate_num%\" pitch=\"$PITCH%\">/g" tmp-aws-$RS.xml > tmp-$RS.xml
		mv tmp-$RS.xml tmp-aws-$RS.xml
	done < tmp-$RS.txt
else
	sed -e "s|<speak version=\"1.1\">|<speak version=\"1.1\">\n<prosody rate=\"0%\" pitch=\"$PITCH%\">|" tmp-aws-$RS.xml > tmp-$RS.xml
	mv tmp-$RS.xml tmp-aws-$RS.xml
	sed -e "s|</speak>|</prosody>\n</speak>|" tmp-aws-$RS.xml > tmp-$RS.xml
	mv tmp-$RS.xml tmp-aws-$RS.xml
fi


prosody_count=1; file_count=1
while :
do
	echo "cat /speak/prosody[${prosody_count}]" |xmllint --shell tmp-aws-$RS.xml > tmp-$RS.txt
	PROSODY_RATE=$(grep "<prosody\ *rate" tmp-$RS.txt)
	
	if [ -z "$PROSODY_RATE" ]; then
		rm -f tmp-$RS.txt
		break
	fi

	cat tmp-$RS.txt |sed '1,2d' |sed -e '$d' |sed -e '$d' > tmp-$RS.xml

	sed -e "s/。/。\n${SPLIT}\n/g" -e "s/\.\ /\.\n${SPLIT}\n/g" \
		-e "s/\!\ /\!\n${SPLIT}\n/g" -e "s/\！\　/\！\n${SPLIT}\n/g" \
		-e "s/\?\ /\?\n${SPLIT}\n/g" -e "s/\？\　/\？\n${SPLIT}\n/g" tmp-$RS.xml > tmp-$RS-tmp.xml
	echo ${SPLIT} >> tmp-$RS-tmp.xml; mv tmp-$RS-tmp.xml tmp-$RS.xml

	cat tmp-$RS.xml |awk '
		{
			last_letter=(substr($NF, length($NF), length($NF)))
			if($0 == "" || last_letter == "." || last_letter == "!" || last_letter == "！" || \
				last_letter == "?" || last_letter == "？"){
				SPLIT_FLAG=1; 
			}else{
				SPLIT_FLAG=0
			}
			if($0 == "" || SPLIT_FLAG == 1){
				print $0 "\n" "'$SPLIT'"
			}else{
				print $0 
			}
		}
	' | grep -v "^\s*$" |sed '/^$/d' > tmp-split-$RS.xml
	rm -f tmp-$RS.xml

	sentence_count=1; SPLIT_FLAG=0
	while read line
	do
		word=${line}
		if [ "$word" != ${SPLIT} ]; then
			SPLIT_FLAG=1
			echo $word >> azure-txt/$PAGE_NUMBER-pro${prosody_count}-sen${sentence_count}.txt
		elif [ $SPLIT_FLAG -eq 1 ]; then
			echo -e "${XML_VER}\n${SPEAK_VER}\n${VOICE}\n${LEXICON_URI}\n" > azure-xml/$PAGE_NUMBER-pro${prosody_count}-sen${sentence_count}.xml
			echo "${PROSODY_RATE}" >> azure-xml/$PAGE_NUMBER-pro${prosody_count}-sen${sentence_count}.xml
			cat azure-txt/$PAGE_NUMBER-pro${prosody_count}-sen${sentence_count}.txt >> azure-xml/$PAGE_NUMBER-pro${prosody_count}-sen${sentence_count}.xml
			echo -e "</prosody>\n</mstts:express-as>\n</voice>\n</speak>" >> azure-xml/$PAGE_NUMBER-pro${prosody_count}-sen${sentence_count}.xml
			mv azure-txt/$PAGE_NUMBER-pro${prosody_count}-sen${sentence_count}.txt azure-txt/$PAGE_NUMBER-$file_count.txt
			mv azure-xml/$PAGE_NUMBER-pro${prosody_count}-sen${sentence_count}.xml azure-xml/$PAGE_NUMBER-$file_count.xml
			sentence_count=$((sentence_count+1)); file_count=$((file_count+1))
			SPLIT_FLAG=0
		fi
	done < tmp-split-$RS.xml
	rm -f tmp-split-$RS.xml

	prosody_count=$((prosody_count+1))
done
rm -f tmp-aws-$RS.xml

