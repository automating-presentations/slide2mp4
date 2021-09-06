#!/bin/bash


AZURE_SSML_XML="$1"
AZURE_REGION="$2"
AZURE_TTS_SUBS_KEY=$(cat "$3" |grep -v '^#' |grep -v "^\s*$" |sed '/^$/d')
AZURE_TTS_MP3="$4"


curl -s --location --request POST "https://${AZURE_REGION}.tts.speech.microsoft.com/cognitiveservices/v1" \
	-H "Ocp-Apim-Subscription-Key: ${AZURE_TTS_SUBS_KEY}" \
	-H "Content-Type: application/ssml+xml" \
	-H "X-Microsoft-OutputFormat: audio-24khz-48kbitrate-mono-mp3" \
	-H "User-Agent: curl" \
	-d @$AZURE_SSML_XML  > "$AZURE_TTS_MP3"

