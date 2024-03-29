# slide2mp4

slide2mp4 is a conversion tool, PDF slides to MP4 with audio and subtitles.   
slide2mp4 uses Azure Speech (default) or Amazon Polly, Text-to-Speech (TTS) service.

----
## Examples
[Sample videos in Japanese and English on YouTube](https://www.youtube.com/playlist?list=PL4IvAXW0drR0TLFEuUOZNA26PBe9W4LJF)

----
## Demo
<img src="demo/slide2mp4-demo.gif" width="640" height="360">

----
## Requirements

 - [Azure Speech](https://azure.microsoft.com/en-us/services/cognitive-services/text-to-speech/) service resource (paid tier) with your Azure account (please refer to [this document](https://learn.microsoft.com/en-us/azure/cognitive-services/cognitive-services-apis-create-account))
   - Your Azure Speech service subscription key
   - Your Azure Speech service region
 - [AWS CLI version 2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) (Optional. version 1 has not been tested.)
 - Permission to run [Amazon Polly](https://docs.aws.amazon.com/polly/latest/dg/what-is.html) service with AWS CLI (Optional)
 - Permission to run [Amazon S3](https://aws.amazon.com/s3/) service with AWS CLI (Optional)
 - [FFmpeg](https://www.ffmpeg.org/)
 - [ffprobe](https://ffmpeg.org/ffprobe.html)
 - [GNU Parallel](https://www.gnu.org/software/parallel/)
 - [Poppler](https://poppler.freedesktop.org/)
 - [Python 3](https://www.python.org/)
 - [xmllint](http://xmlsoft.org/xmllint.html)

Note: If you choose a free (F0) pricing tier for Azure Speech, please be aware that you may not be able to complete the execution of slide2mp4 as Azure Speech will prevent you from getting more than a certain number of audio (mp3) files.

When using Linux or macOS(including M1 Mac), you can install AWS CLI, FFmpeg, GNU Parallel, Poppler, with [Homebrew](https://brew.sh/).

```
brew install awscli ffmpeg parallel poppler
```

If you don't want to make any changes to your local environment, you can download a container image with a complete environment for using slide2mp4.
```
docker pull ghcr.io/automating-presentations/slide2mp4:latest
```

----
## How to use

### slide2mp4

The following command uses Azure Speech to create one mp4 file with audio and subtitles, named "test-output.mp4". The subscription key to use Azure Speech must be found in "~/.azure/tts-subs-keyfile". The default Azure Speech service region for slide2mp4 is Japan East region, so when you run the following command, please create your Azure Speech subscription key in Japan East region.

```
mkdir -p ~/.azure; cat << EOF  > ~/.azure/tts-subs-keyfile
# Azure Speech subscription key
XXXXXXXXXXXXXXXXXXXXXXXXX
EOF
```
```
git clone --depth 1 https://github.com/automating-presentations/slide2mp4
chmod u+x slide2mp4/slide2mp4.sh slide2mp4/lib/*.sh slide2mp4/tools/*.sh
cd slide2mp4/test
../slide2mp4.sh test-slides.pdf test-slides.txt test-output.mp4
: '↓ when using lexicon'
../slide2mp4.sh -lexicon https://raw.githubusercontent.com/automating-presentations/slide2mp4/main/test/test-lexicon.pls test-slides.pdf test-slides.txt test-output.mp4
```

When you specify the output directory, files created by slide2mp4 will be saved in the specified directory. If the directory does not exist, it will be created automatically.
```
slide2mp4 -p ./outputs-directory test-slides.pdf test-slides.txt test-output.mp4
```

The following command uses Azure Speech to create one mp4 file with audio and subtitles, named "test-output.mp4" using only specific pages, e.g. using only 1, 2 page.
```
slide2mp4 -sp test-slides.pdf test-slides.txt test-output.mp4 "1 2"
```

If you have modified some of the slides, e.g. pages 1 and 3, you can apply the patch to "test-output.mp4" with the following command. When you run this command with Azure Speech (not Amazon Polly), "test-lexicon.pls" will be temporarily uploaded to Amazon S3.

```
cd slide2mp4/test
../slide2mp4.sh -lexicon test-lexicon.pls test-slides.pdf test-slides.txt test-output.mp4 "1 3"
```

When you don't use Amazon S3, you can specify public (non-private) URL for downloading the lexicon file.
```
cd slide2mp4/test
../slide2mp4.sh -lexicon https://public_domain/test.pls test-slides.pdf test-slides.txt test-output.mp4 "1 3"
```

No subtitles option is also available, e.g. mp4 files on pages 1 and 3 are without subtitles.
```
cd slide2mp4/test
../slide2mp4.sh -ns -lexicon test-lexicon.pls test-slides.pdf test-slides.txt test-output.mp4 "1 3"
```

No PDF converting option is also available, e.g. in the case of changing the talk script on pages 1 and 3.
```
cd slide2mp4/test
../slide2mp4.sh -npc -ns -lexicon test-lexicon.pls test-slides.pdf test-slides.txt test-output.mp4 "1 3"
```

The following command specifies the geometry of output mp4 files (1080p), the Azure Region where to put your subscription key, voice ID/pitch, subscription keyfile path to use Azure Speech. Please refer to [this web page](https://learn.microsoft.com/en-us/azure/cognitive-services/speech-service/language-support?tabs=tts#supported-languages) to see what kind of voice ID is available.
```
cd slide2mp4/test
../slide2mp4.sh -azure -geo 1920x1080 -azure-region centralus -azure-vid en-US-JennyNeural -azure-pitch -6 -azure-tts-key test-azure-keyfile test.pdf test.txt output.mp4
```

The following command uses Amazon Polly to create one mp4 file with audio and subtitles, named "test-output.mp4".
```
cd slide2mp4/test
../slide2mp4.sh -aws test-slides.pdf test-slides.txt test-output.mp4
```

Specify the Amazon Polly Neural format, voice ID, Matthew (Male, English, US). Note that the Neural format only works with some voice IDs.
```
cd slide2mp4/test
../slide2mp4.sh -aws -aws-vid Matthew -aws-neural -lexicon lexicon.pls test.pdf test.txt output.mp4
```

----
### Related tools for slide2mp4

You can create a lexicon file automatically. Once you've created a dictionary file in Japanese, "test-dic.txt" in the following example, you can create a lexicon file with the language code "ja-JP", named "test-sample-lexicon.pls" with the following command. If you would like to use the existing dictionary files, please refer to [slide2mp4-dictionary](https://github.com/automating-presentations/slide2mp4-dictionary).
```
cd slide2mp4/test
../tools/lexicon-generate.sh -lang ja-JP test-dic.txt test-slides.txt test-sample-lexicon.pls
```

You can convert the existing lexicon file to a dictionary file, or extend the existing dictionary file with the following command. Please note that if the word and pronounciation in your lexicon file contain spaces and tabs, the spaces and tabs will be removed. 
```
cd slide2mp4/test
../tools/lexicon2dic.sh test-lexicon.pls test-sample-dic.txt
```

You can create a directory containing a text file containing the talk scripts for each page, and a compressed zip file of that directory with the following command.
```
cd slide2mp4/test
../tools/talkscripts-extraction.sh test-slides.txt talkscripts
```

Optionally, once you've created mp4 files, "test-output.mp4" in the above example, you can create a text file with timestamp for each chapter, named "test-timestamps.txt" with the following command. This text file with timestamps can be used to [turn on chapters for your videos on YouTube](https://support.google.com/youtube/answer/9884579?hl=en). Chapters-timestamp.sh needs to be run with the PATH of the directory including mp4 files.
```
cd slide2mp4/test
../tools/chapters-timestamp.sh mp4 test-timestamps.txt
```

----
## Documentation
 - [Japanese User Guide](https://github.com/automating-presentations/slide2mp4/blob/main/doc/userguide-ja.md)

----
## License
 - [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0)
