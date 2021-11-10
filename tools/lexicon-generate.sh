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
	echo "	$(basename $0) creates a lexicon file only the words in the dictionary file."
	echo "Usage:"
	echo "	$(basename $0) [option] DIC_TXT TALK_SCRIPT_TXT LEXICON_FILE"
	echo "Options:"
	echo "	-h, --help			print this message."
        echo "	-lang <language code>		specify the language code of a lexicon file. (default language code is \"ja-JP\")"
        echo "	-patch <dictionary text file>	specify the patch file to be applied to DIC_TXT."
	echo ""
	echo "Example1: The following command creates a lexicon file \"test-lexicon.pls\" with the language code \"ja-JP\", only the words in \"test-dic.txt\"."
        echo "  $(basename $0) test-dic.txt test-my-talk-scripts.txt test-lexicon.pls"
        echo ""
        echo "Example2: The following command creates a lexicon file with the language code \"en-US\"."
        echo "  $(basename $0) -lang en-US test-dic-en.txt test-my-talk-scripts-en.txt test-lexicon-en.pls"
	echo ""
        echo "Example3: The following command specifies the patch to be applied to \"test-dic.txt\". The items in \"test-dic.txt\" will be overwritten by the items in \"patch-dic.txt\"."
        echo "  $(basename $0) -patch patch-dic.txt test-dic.txt test-my-talk-scripts.txt test-lexicon.pls"
	echo ""
	exit
}


# Random String
RS=$(cat /dev/urandom |base64 |tr -cd "a-z0-9" |fold -w 32 |head -n 1)


if [ $# -ne 0 ]; then
	if [ "$1" == "-h" -o "$1" == "--help" ]; then
		print_usage
	fi
fi
if [ $# -lt 3 ]; then
	echo "Too few arguments. Please check whether the number of arguments is 3 or more."
	echo "Please check '$(basename $0) -h' or '$(basename $0) --help'."
	exit
fi


XML_LANG="ja-JP"
touch empty-$RS.txt; PATCH_TXT=empty-$RS.txt
i=0
while [ $# -gt 0 ]
do
        if [ "$1" == "-lang"  ]; then
                shift; XML_LANG="$1"; shift
	elif [ "$1" == "-patch" ]; then
		shift; PATCH_TXT="$1"; shift
        else
                i=$(($i+1)); arg[i]="$1"; shift
        fi
done
DIC_TXT="${arg[1]}"
TALK_SCRIPT_TXT="${arg[2]}"
LEXICON_FILE="${arg[3]}"


cat "$DIC_TXT" |grep -v '^#' |grep -v "^\s*$" |sed '/^$/d' > tmp-DIC_TXT-$RS.txt
if [ -s "$PATCH_TXT" ]; then
	cat "$PATCH_TXT" |grep -v '^#' |grep -v "^\s*$" |sed '/^$/d' > tmp-PATCH-$RS.txt

	while read line
	do
		set ${line}
		word=${1}; alias=${2}
		if [ -n "$word"  -a  -n "$alias" ]; then
			grep -v "$word" tmp-DIC_TXT-$RS.txt > tmp-word-delete-$RS.txt
			echo "${line}" >> tmp-word-delete-$RS.txt; mv tmp-word-delete-$RS.txt tmp-DIC_TXT-$RS.txt
		fi
	done < tmp-PATCH-$RS.txt

	rm -f tmp-PATCH-$RS.txt
fi
rm -f empty-$RS.txt


sed -e 's|^ *~~~TTS$|<?xml|g' -e 's|^ *~~~$|</speak>|g' "$TALK_SCRIPT_TXT" |\
        awk '/<\?xml/,/<\/speak>/' |\
        sed -e 's|#.*||g' |\
	grep -v "^\s*~~~SPEED" |\
	grep -v "^\s*~~~BREAK" > tmp-TALK_SCRIPT_TXT-$RS.txt


echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > "$LEXICON_FILE"
echo "<lexicon version=\"1.0\"" >> "$LEXICON_FILE"
echo "      xmlns=\"http://www.w3.org/2005/01/pronunciation-lexicon\"" >> "$LEXICON_FILE"
echo "      xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"" >> "$LEXICON_FILE"
echo "      xsi:schemaLocation=\"http://www.w3.org/2005/01/pronunciation-lexicon" >> "$LEXICON_FILE"
echo "        http://www.w3.org/TR/2007/CR-pronunciation-lexicon-20071212/pls.xsd\"" >> "$LEXICON_FILE"
echo "      alphabet=\"ipa\" xml:lang=\"$XML_LANG\">" >> "$LEXICON_FILE"
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

