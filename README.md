# Slide2mp4

Slide2mp4 is a conversion tool, PDF slides to mp4 with audio and subtitles.   
Slide2mp4 uses Amazon Polly, Text-to-Speech (TTS) service.

----

## How to use

The following command creates one mp4 file with audio and subtitles, named "test-output.mp4".

```
chmod u+x slide2mp4.sh
./slide2mp4.sh test-slides.pdf test-slides.txt test-lexicon.pls test-output.mp4
```

If you have modified some of the slides, e.g. pages 2 and 3, you can apply the patch to the mp4 file with the following command.

```
./slide2mp4.sh test-slides.pdf test-slides.txt test-lexicon.pls test-output.mp4 "2 3"
```
