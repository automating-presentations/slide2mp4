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


MP4_DIR="$1"
TIMESTAMPS_TXT="$2"


timeinfo=0


print_usage ()
{
	echo "Description:"
	echo "	$(basename $0) creates a text file with timestamp for each chapter."
	echo "	$(basename $0) requires the following command, ffprobe."
	echo "Usage:"
	echo "	$(basename $0) PATH_OF_MP4_DIRECTORY OUTPUT_TXT"
	exit
}


calc_and_print_timestamp ()
{
	var=$(ffprobe -loglevel error -hide_banner -show_entries format=duration "$1" |grep -i duration |sed -e 's/duration=//')
	timeinfo=`echo "scale=6; $timeinfo + $var" |bc`

	tmpvalue=`echo "scale=6; $timeinfo + 0.999999" |bc`
	timestamp=${tmpvalue%.*}

	((min_timestamp=timestamp / 60 ))
	((sec_timestamp=timestamp % 60 ))

	printf "%02d" "${min_timestamp}" >> "$2"
	echo -n ":" >> "$2"
	printf "%02d" "${sec_timestamp}" >> "$2"
}


# Random String
RS=$(cat /dev/urandom |base64 2> /dev/null |tr -cd "a-z0-9" |fold -w 32 |head -n 1)


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


ls "$MP4_DIR" |sort -n > sort_mp4_dir_tmp-$RS.txt


echo "Chapters:" > "$TIMESTAMPS_TXT"
echo -n "00:00" >> "$TIMESTAMPS_TXT"
while read line
do
	echo " "$MP4_DIR"/$line" >> "$TIMESTAMPS_TXT"
	calc_and_print_timestamp ""$MP4_DIR"/$line" "$TIMESTAMPS_TXT"
done < sort_mp4_dir_tmp-$RS.txt


sed -ie '$d' "$TIMESTAMPS_TXT"
rm -f "$TIMESTAMPS_TXT"e sort_mp4_dir_tmp-$RS.txt

