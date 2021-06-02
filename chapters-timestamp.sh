#!/bin/bash
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


TIMESTAMPS_TXT="$1"
((mp4_num=$(ls -F mp4/ | grep -v / | wc -l)-1))


rm -f "$TIMESTAMPS_TXT"
echo "Chapters:" >> "$TIMESTAMPS_TXT"
echo "0:00 1.mp4" >> "$TIMESTAMPS_TXT"

timeinfo=0
for i in `seq 1 $mp4_num`
do
	var=$(ffprobe -hide_banner -show_entries format=duration mp4/$i.mp4 |grep -i duration |sed -e 's/duration=//')
	timeinfo=`echo "scale=6; $timeinfo + $var" |bc`

	tmpvalue=`echo "scale=6; $timeinfo + 0.999999" |bc`
	timestamp=${tmpvalue%.*}
	# timestamp=$(printf '%.0f\n' $timeinfo)

	((min_timestamp=timestamp / 60 ))
	((sec_timestamp=timestamp % 60 ))
	echo -n "$min_timestamp:" >> "$TIMESTAMPS_TXT"
	printf "%02d" "${sec_timestamp}" >> "$TIMESTAMPS_TXT"
	echo " $(($i+1)).mp4" >> "$TIMESTAMPS_TXT"
done

