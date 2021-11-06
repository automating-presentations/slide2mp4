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


DIC_TXT="$1"
TALK_SCRIPT_TXT="$2"
LEXICON_FILE="$3"


print_usage ()
{
	echo "Description:"
	echo "	$(basename $0) creates a lexicon file."
	echo "Usage:"
	echo "	$(basename $0) DIC_TXT TALK_SCRIPT_TXT LEXICON_FILE"
	exit
}


# Random String
RS=$(cat /dev/urandom |base64 |tr -cd "a-z0-9" |fold -w 32 |head -n 1)


if [ $# -ne 0 ]; then
	if [ "$1" == "-h" -o "$1" == "--help" ]; then
		print_usage
	fi
fi
if [ $# -ne 3 ]; then
	echo "Too few or many arguments. Please check whether the number of arguments is 3."
	echo "Please check '$(basename $0) -h' or '$(basename $0) --help'."
	exit
fi


cat "$DIC_TXT" |grep -v '^#' |grep -v "^\s*$" |sed '/^$/d' > tmp-DIC_TXT-$RS.txt
sed -e 's|^ *--- TTS$|<?xml|g' -e 's|^ *---$|</speak>|g' "$TALK_SCRIPT_TXT" |\
        awk '/<\?xml/,/<\/speak>/' |\
        sed -e 's|#.*||g' |\
	grep -v "^\s*--- SPEED" > tmp-TALK_SCRIPT_TXT-$RS.txt


echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > "$LEXICON_FILE"
echo "<lexicon version=\"1.0\"" >> "$LEXICON_FILE"
echo "      xmlns=\"http://www.w3.org/2005/01/pronunciation-lexicon\"" >> "$LEXICON_FILE"
echo "      xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"" >> "$LEXICON_FILE"
echo "      xsi:schemaLocation=\"http://www.w3.org/2005/01/pronunciation-lexicon" >> "$LEXICON_FILE"
echo "        http://www.w3.org/TR/2007/CR-pronunciation-lexicon-20071212/pls.xsd\"" >> "$LEXICON_FILE"
echo "      alphabet=\"ipa\" xml:lang=\"ja-JP\">" >> "$LEXICON_FILE"
echo >> "$LEXICON_FILE"


while read line
do
	set ${line}
	word=${1}; alias=${2}
	if [ -n "$word"  -a  -n "$alias" ]; then
		check_word=$(grep "$word" tmp-TALK_SCRIPT_TXT-$RS.txt 2> /dev/null)
		if [ -n "$check_word" ]; then
			echo "  <lexeme>" >> "$LEXICON_FILE"
			echo "    <grapheme>"$word"</grapheme>" >> "$LEXICON_FILE"
			echo "    <alias>"$alias"</alias>" >> "$LEXICON_FILE"
			echo "  </lexeme>" >> "$LEXICON_FILE"
			echo >> "$LEXICON_FILE"
		fi
	fi
done < tmp-DIC_TXT-$RS.txt
echo "</lexicon>" >> "$LEXICON_FILE"


rm -f tmp-DIC_TXT-$RS.txt tmp-TALK_SCRIPT_TXT-$RS.txt

