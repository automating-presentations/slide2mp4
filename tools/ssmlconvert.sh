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


print_usage ()
{
        echo "Description:"
        echo "  $(basename $0) inserts or removes SSML tags for Amazon Polly."
        echo "  If you would like to insert SSML tags for creating multiple audio files by using TTS service,"
	echo "  please insert your specific tag in the text file where you would like to split the sound file."
	echo "  If no tag is specified, the SSML header and tail will be inserted at the beginning and end of the file."
        echo "Usage:"
        echo "  $(basename $0) [option] -i <input text or ssml file> -o <output ssml or text file>"
        echo "Options:"
        echo "  -h, --help			print this message."
        echo "  -remove-ssml			removes all SSML tags."
        echo "  -tag <your specific tag>	specify tag for split."
        echo ""
        echo "Example1: The following command inserts SSML header and tail, and outputs to \"test-output.xml\"."
        echo ""
        echo "  $(basename $0) -i input.txt -o test-output.xml"
        echo ""
        echo "Example2: The following command removes all SSML tags and outputs to \"test-output.txt\"."
        echo ""
        echo "  $(basename $0) -remove-ssml -i input.xml -o test-output.txt"
        echo ""
        echo "Example3: The following command inserts multiple SSML header and tail, and outputs to \"test-output.xml\"."
	echo "	Each of SSML header and tail will be inserted where you put \"INSERT_SSML_TAGS\" in input.txt."
        echo ""
        echo "  $(basename $0) -tag "INSERT_SSML_TAGS" -i input.txt -o test-output.xml"
        exit
}


# Random String
RS=$(cat /dev/urandom |base64 |tr -cd "a-z0-9" |fold -w 32 |head -n 1)
TAG=$RS


INPUT_FLAG=0; OUTPUT_FLAG=0; REMOVE_SSML_FLAG=0
while [ $# -gt 0 ]
do
	if [ "$1" == "-h" -o "$1" == "--help" ]; then
		print_usage
	elif [ "$1" == "-i" ]; then
		INPUT_FLAG=1; shift; INPUT_FILE="$1"; shift
	elif [ "$1" == "-o" ]; then
		OUTPUT_FLAG=1; shift; OUTPUT_FILE="$1"; shift
	elif [ "$1" == "-remove-ssml" ]; then
		REMOVE_SSML_FLAG=1; shift
	elif [ "$1" == "-tag" ]; then
		shift; TAG="$1"; shift
	else
		shift
	fi
done
if [ $INPUT_FLAG -eq 0  -o  ! -f "$INPUT_FILE" ]; then
	echo "Please specify input file, -i <input file>."
	echo "Please check '$(basename $0) -h' or '$(basename $0) --help'."
	exit
elif [ $OUTPUT_FLAG -eq 0 ]; then
	echo "Please specify output file name, -o <output file>."
        echo "Please check '$(basename $0) -h' or '$(basename $0) --help'."
        exit
fi


SSML_TMP_TAG="<ssml-tag-v49ms2y2fk6fmljhvat7zyorlp4ju15g>"
if [ $REMOVE_SSML_FLAG -eq 0 ]; then
	SSML_HEADER="<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<speak version=\"1.1\">\n<prosody rate=\"100%\">"
	SSML_FOOTER="</prosody>\n</speak>"

	sed -e "s/${TAG}/${SSML_TMP_TAG}/g" "$INPUT_FILE" | \
		sed -e ':a' -e 'N' -e '$!ba' -e "s/<ssml-tag-v49ms2y2fk6fmljhvat7zyorlp4ju15g>/<\/prosody>\n<\/speak>\n\n<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<speak version=\"1.1\">\n<prosody rate=\"100%\">/g" > tmp-ssml-$RS.xml
	echo -e $SSML_HEADER > "$OUTPUT_FILE"
	cat tmp-ssml-$RS.xml >> "$OUTPUT_FILE"
	echo -e $SSML_FOOTER >> "$OUTPUT_FILE"
	rm -f tmp-ssml-$RS.xml

	echo "SSML tags have been inserted. Please check $OUTPUT_FILE."
else
	sed -e "s/<?xml.*/${SSML_TMP_TAG}/g" -e "s/<\/*speak.*/${SSML_TMP_TAG}/g" \
		-e "s/<\/*prosody.*/${SSML_TMP_TAG}/g" -e "s/<\/*voice.*/${SSML_TMP_TAG}/g" \
		-e "s/<\/*lexicon.*/${SSML_TMP_TAG}/g" "$INPUT_FILE" > tmp-ssml-$RS.xml
	sed -e ':a' -e 'N' -e '$!ba' -e 's/<ssml-tag-v49ms2y2fk6fmljhvat7zyorlp4ju15g>\n//g' tmp-ssml-$RS.xml | \
		sed -e ':a' -e 'N' -e '$!ba' -e 's/\n<ssml-tag-v49ms2y2fk6fmljhvat7zyorlp4ju15g>//g' > "$OUTPUT_FILE"
	rm -f tmp-ssml-$RS.xml

	echo "SSML tags have been removed. Please check $OUTPUT_FILE."
fi

