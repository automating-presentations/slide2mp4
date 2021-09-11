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
SCRIPTS_DIR="$(cd "$(dirname "$0")"; pwd)"


print_usage ()
{
	echo "Description:"
	echo "	$(basename $0) creates a directory containing a text file containing the talk scripts for each page,"
	echo "	and a compressed zip file of that directory."
	echo "	$(basename $0) requires $SCRIPTS_DIR/lib/txt2xml.py and $SCRIPTS_DIR/ssmlconvert."
	echo "	txt2xml.py and ssmlconvert are included in slide2mp4 repository."
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


cat "$TXT_FILE" |awk '/<\?xml/,/<\/speak>/' > tmp-xml.txt
rm -rf xml; mkdir -p xml
python3 $SCRIPTS_DIR/lib/txt2xml.py tmp-xml.txt; rm -f tmp-xml.txt
page_num=$(ls -F xml/ |grep -v / |wc -l |awk '{print $1}')
# echo "page_num is $page_num."


mkdir -p txt-$RS
for i in `seq 1 $page_num`
do
	$SCRIPTS_DIR/ssmlconvert -remove-ssml -i xml/$i.xml -o txt-$RS/$i-tmp.txt > /dev/null
	echo "$PRE_MESSAGE" > txt-$RS/page$i.txt
	cat txt-$RS/$i-tmp.txt >> txt-$RS/page$i.txt
done


rm -rf txt-$RS/*-tmp.txt "$OUTPUT" "$OUTPUT".zip
mv txt-$RS "$OUTPUT"
zip -r "$OUTPUT" "$OUTPUT"
rm -rf xml

