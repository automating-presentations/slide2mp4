# slide2mp4

slide2mp4 is a conversion tool, PDF slides to MP4 with audio and subtitles.   
slide2mp4 uses Amazon Polly, Text-to-Speech (TTS) service.

----
## Requirements

 - [AWS CLI version 2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) (version 1 has not been tested.)
 - Permission to run [Amazon Polly](https://docs.aws.amazon.com/polly/latest/dg/what-is.html) service with AWS CLI
 - [FFmpeg](https://www.ffmpeg.org/)
 - [GraphicsMagick](http://www.graphicsmagick.org/index.html)
 - [Ghostscript](https://www.ghostscript.com/)
 - [Python 3](https://www.python.org/)
 - [xmllint](http://xmlsoft.org/xmllint.html)

If you use Linux or macOS(including M1 Mac), you can install AWS CLI, FFmpeg, Ghostscript, GraphicsMagick, with [Homebrew](https://brew.sh/).

```
brew install awscli ffmpeg ghostscript graphicsmagick
```

----
## How to use

The following command creates one mp4 file with audio and subtitles, named "test-output.mp4".

```
git clone https://github.com/h-kojima/slide2mp4
chmod u+x slide2mp4/slide2mp4.sh
cd slide2mp4/test
../slide2mp4.sh test-slides.pdf test-slides.txt test-lexicon.pls test-output.mp4
```

If you have modified some of the slides, e.g. pages 2 and 3, you can apply the patch to "test-output.mp4" with the following command.

```
../slide2mp4.sh test-slides.pdf test-slides.txt test-lexicon.pls test-output.mp4 "2 3"
```

No subtitles option is also available, e.g. mp4 files on pages 1 and 3 are without subtitles.
```
../slide2mp4.sh -ns test-slides.pdf test-slides.txt test-lexicon.pls test-output.mp4 "1 3"
```

Optionally, once you've created mp4 files, "test-output.mp4" in the above example, you can create a text file with timestamp for each chapter, named "test-timestamps.txt" in the following example. This text file with timestamps can be used to [turn on chapters for your videos on YouTube](https://support.google.com/youtube/answer/9884579?hl=en). Chapters-timestamp.sh needs to be run in a location with an mp4 directory (mp4/{1..N}.mp4).
```
cd slide2mp4/test
../chapters-timestamp.sh test-timestamps.txt
```

----
## Documentation
 - [Japanese User Guide](https://github.com/h-kojima/slide2mp4/blob/main/doc/userguide-ja.md)

----
## License
 - [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0)
