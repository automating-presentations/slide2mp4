#!/bin/bash

((mp4_num=$(ls -F mp4/ | grep -v / | wc -l)-1))

rm -f timestamp.txt
echo "Chapters:" >> timestamp.txt
echo "0:00 1.mp4" >> timestamp.txt

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
	echo -n "$min_timestamp:" >> timestamp.txt
	printf "%02d" "${sec_timestamp}" >> timestamp.txt
	echo " $(($i+1)).mp4" >> timestamp.txt
done

