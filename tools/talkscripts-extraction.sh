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


TXT_FILE="$1"
OUTPUT="$2"
PRE_MESSAGE="The talk scripts of this page are as follows:"


print_usage ()
{
	echo "Description:"
	echo "	$(basename $0) creates a directory containing a text file containing the talk scripts for each page,"
	echo "	and a compressed zip file of that directory."
	echo "Usage:"
	echo "	$(basename $0) TXT_FILE OUTPUT_DIRECTORY_AND_ZIP_NAME"
	echo "	This \"TXT_FILE\" is the same text file that will be input to slide2mp4."
	exit
}


# Random String
RS=$(cat /dev/urandom |base64 |tr -cd "a-z0-9" |fold -w 32 |head -n 1)


if [ $# -ne 0 ]; then
	if [ "$1" == "-h" -o "$1" == "--help" ]; then
		print_usage
	fi
fi
if [ $# -ne 2 ]; then
	echo "Too few or many arguments. Please check whether the number of arguments is 2."
	echo "Please check '$(basename $0) -h' or '$(basename $0) --help'."
	exit
fi


awk '/\s*--- TTS/,/\s*------/' "$TXT_FILE" |\
	grep -v "\s*--- SPEED" |\
	sed -e 's|#.*||g' > tmp-$RS.txt
rm -rf "$OUTPUT" "$OUTPUT".zip
mkdir -p "$OUTPUT"; i=0
while read line
do
	echo ${line} > line-$RS.txt;
	check_tts_begin=$(grep "^\s*--- TTS" line-$RS.txt 2> /dev/null)
	check_tts_end=$(grep "^\s*------" line-$RS.txt 2> /dev/null)
	if [ -n "$check_tts_begin" ]; then
		i=$(($i+1))
		echo "$PRE_MESSAGE" > "$OUTPUT"/page$i.txt
		echo >> "$OUTPUT"/page$i.txt
	else
		if [ -z "$check_tts_end" ]; then
			echo ${line} >> "$OUTPUT"/page$i.txt
		fi
	fi
done < tmp-$RS.txt
rm -f tmp-$RS.txt line-$RS.txt
zip -r "$OUTPUT" "$OUTPUT"


