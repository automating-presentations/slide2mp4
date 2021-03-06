# slide2mp4 のユーザーガイド 

slide2mp4.sh を利用した、機械音声による読み上げ動画作成の仕組みを紹介します。  
slide2mp4.sh の変数や処理の変更などは、本ガイドを参考にしてください。

----
## テストデータの利用方法

[システム要件](https://github.com/automating-presentations/slide2mp4#requirements)を満たしている場合、テストデータを利用したテストを実行できます。slide2mp4.sh では字幕のデフォルトフォントを「NotoSansCJKjp-Regular, 14サイズ」と指定しています。[Noto Sans CJK JP](https://www.google.com/get/noto/help/cjk/)のフォントが無い場合はシステムデフォルトのフォントが使われると思いますが、その場合は、slide2mp4.sh のフォントに関する変数を適宜変更してください。

```
mkdir -p ~/.azure; cat << EOF  > ~/.azure/tts-subs-keyfile
# Azure Speech subscription key
XXXXXXXXXXXXXXXXXXXXXXXXX
EOF
```
```
git clone --depth 1 https://github.com/automating-presentations/slide2mp4
chmod u+x slide2mp4/slide2mp4.sh
cd slide2mp4/test
../slide2mp4.sh test-slides.pdf test-slides.txt test-output.mp4
: '↓ lexiconを指定する場合'
../slide2mp4.sh -lexicon https://raw.githubusercontent.com/automating-presentations/slide2mp4/main/test/test-lexicon.pls test-slides.pdf test-slides.txt test-output.mp4
```

----
## 入力ファイルと出力ファイル

入力ファイル:
 - Google Slides
   - Google SlidesからDLした、PDFとPlain Textファイルが必要。ただし、スライドのPDFと下記のスライドノートがまとめられたテキストファイルを用意できるのであれば、Google Slideを利用する必要なし
   - Google Slidesでは、スライドノートを一括保存可能。スライド左上メニューの [File] -> [Download] -> [Plain Text] により、
     スライドとスライドノートのテキスト部分が 1つのテキストファイルにまとめられたものをDL可能
   - PDFのDL時にフォントが崩れる場合は、一度pptxでDLした後に、PowerPointを開いてPDF Export
   - LibreOfficeを利用している場合は、pptx形式で保存した後に、Google DriveにアップロードしてGoogle Slidesでpptxファイルを開くと、上記と同様にスライドノートの一括保存が可能
 - マークアップ言語、または、SSMLタグを含んだXMLで書かれたトークスクリプト (Google Slidesのスライドノート内に記載)
 - (オプション) 発音エイリアスを記載した[lexicon](https://www.w3.org/TR/pronunciation-lexicon/)
   - 日本語音声だと、英字の製品名をうまく読んでくれない時があるので、エイリアスを記載したファイルを適宜作成

出力ファイル:
 - PDFから変換した画像ファイル (png)
 - 音声ファイル (mp3)
 - スピーチマーク(タイプスタンプ)付きのトークスクリプトファイル (json)
 - 字幕ファイル (srt)
 - 動画ファイル (音声と字幕付き. mp4)

----
## 720pの読み上げ動画の作り方(テストガイド)

トークスクリプト込みのスライド作成方法と、slide2mp4.sh の実行処理の流れを順に紹介します。

----
### 1. Google Slidesを作成
スライド作成時に、test.txtのような形式でトークスクリプトをスライドノート内に記載します。[サンプルファイル](https://github.com/automating-presentations/slide2mp4/blob/main/test/xml/1.xml)のように、SSMLタグを直接指定するxml形式のファイルも利用できますが、簡単化のため、こちらの形式の利用を推奨します。  
なお、1文(1文の終了は句読点の「。」、または、2つ以上連続する改行文字)の中の改行も字幕に反映されるので、区切りたいポイントで改行をしておきます。
本ガイドでの手順により、1文ごとに1つの字幕が表示されます。1文が長くなり、3行や4行とかになると、スライド下部の文字が見にくくなりますので、スライドの情報量にもよりますが、1文は2行程度に抑えておくと、字幕やスライド下部の文字が見やすくなります。
```
cat << EOF  > test.txt
~~~TTS
これはタイトルスライドであり、
これから、サンプルスライドをご紹介します。
OpenShiftとVirtualizationの読み上げテストもします。
~~~
EOF
```

機械音声が読み上げるテキストは、「~~~TTS」から始まり、「~~~」で終わります。文中に「~~~TTS」と「~~~」がある場合、機械音声読み上げの開始や終了フラグとして扱われません。「#」以降の文字列は行末までコメントアウトされ、機械音声では読み上げられません。  
また、「~~~SPEED」を1つまたは複数指定することで、機械音声の読み上げ速度を変更できます。「~~~SPEED」を指定しない場合は、デフォルトの1倍速で読み上げられます。
```
cat << EOF  > test.txt
~~~TTS
~~~SPEED 1.1x
# ここからは、1.1倍速で読み上げられます。
これはタイトルスライドであり、
これから、サンプルスライドをご紹介します。
~~~SPEED 1x
# ここからは、デフォルトの1倍速で読み上げられます。
コメントアウトのテストをします。
~~~SPEED 1.25x
# ここからは、1.25倍速で読み上げられます。
OpenShiftとVirtualizationの読み上げテストもします。
~~~
EOF
```

「~~~BREAK」で一時停止を指定して、プレゼンの間を取ることに利用できます。一時停止できる時間の範囲は、利用するTTSサービス([Azure Speech](https://docs.microsoft.com/ja-jp/azure/cognitive-services/speech-service/speech-synthesis-markup?tabs=csharp#add-or-remove-a-breakpause)や[Amazon Polly](https://docs.aws.amazon.com/ja_jp/polly/latest/dg/supportedtags.html))の仕様に準拠します。
```
cat << EOF  > test.txt
~~~TTS
これはタイトルスライドであり、
~~~BREAK 1s # 1秒の一時停止
これから、サンプルスライドをご紹介します。
~~~BREAK 1000ms # 1000ミリ秒の一時停止
OpenShiftとVirtualizationの読み上げテストもします。
~~~
EOF
```

スライド作成後は、PDFとPlain Textファイルをダウンロードします。

英字の製品名などで機械音声でうまく読み上げられないものについては、予めlexiconを利用して発音のエイリアスを作っておきます。ここでは、OpenShiftとVirtualizationの発音エイリアスを利用する例をご紹介します。  

lexiconは、[lexicon-generate.sh](https://github.com/automating-presentations/slide2mp4/blob/main/tools/lexicon-generate.sh)を利用して、ユーザが作成した辞書ファイルから自動的に作成できます。辞書ファイルは単語と発音を記載したテキストファイルであり、単語と発音の間は空白かタブで区切る必要があります。単語と発音の中には、空白やタブを含めることはできません。[lexiconのサイズの上限値](https://docs.aws.amazon.com/ja_jp/polly/latest/dg/limits.html)を考慮して、単語と発音の組み合わせ数を抑えるために、この制限を設定しています。辞書ファイルでは、「#」から始まる行はコメントとして認識されます。  

下記は、test-dic.txtという名前の辞書ファイルと、Google Slidesからダウンロードしたトークスクリプトtest-slides.txtから、lexiconを自動的に作成するコマンド例です。このコマンドにより、予め作成した辞書ファイルにある単語のうち、トークスクリプトに記載される単語のみを抽出したlexiconが自動的に作成されます。

```
cat << EOF   > test-dic.txt
# word	pronunciation
OpenShift	オープンシフト
Virtualization	バーチャライゼーション
EOF
lexicon-generate.sh -lang ja-JP test-dic.txt test-slides.txt test-sample-lexicon.pls
```

上記のtest-sample-lexicon.plsのように、自動作成したlexiconのほかにも、[サンプルのlexiconファイル](https://github.com/automating-presentations/slide2mp4/blob/main/test/test-lexicon.pls)のように、直接作成したlexiconを利用することもできます。

また、[lexicon2dic.sh](https://github.com/automating-presentations/slide2mp4/blob/main/tools/lexicon2dic.sh)を利用して、既存のlexiconを上記フォーマットに沿った辞書ファイルに変換できます。この時、lexiconファイルで登録している単語や発音の中に空白やタブが含まれている場合、その空白やタブは削除されますので注意してください。
```
lexicon2dic.sh test-lexicon.pls test-dic.txt
```

既存の辞書ファイルを使いたい場合は、[slide2mp4-dictionary](https://github.com/automating-presentations/slide2mp4-dictionary)を参照してください。

----
### 2. json/mp3/mp4/png/srt/xml ファイルを保存するディレクトリを作成
```
mkdir -p json mp3 mp4 png srt xml
```

----
### 3. PDFファイルからpngファイルへの一括変換
複数ページのPDFファイル(test-slides.pdf)を次のコマンドで複数の720pのpngファイルに一括変換します。この例では、3ページのPDFファイルをpng/image-{1..3}.pngに変換します。
解像度を1080p(1920x1080)にする場合は、-scale-to-x, -scale-to-yオプションを、それぞれ 1920 と 1080 に変更します。

```
rm -f png/*
pdftocairo -png -r 600 -scale-to-x 1280 -scale-to-y 720 PDF-$RS.pdf png/image
for i in `seq 1 3`; do mv png/image-0$i.png png/image-$i.png 2> /dev/null; done
```

----
### 4. トークスクリプトをxmlファイルに変換

Google SlidesからPlain Text形式でDLしたtest-slides.txtに含まれる、トークスクリプト(xml)部分を抽出します。  
スクリプト部分である`<?xml`から始まり`</speak>`で終わる文字列を抽出します。  
なお、ここでは記載していませんが、slide2mp4ではこの抽出処理の前に、「~~~TTS」を「<?xml」に変更するなど、SSMLタグへの変換処理を実施しています。

```
: '# awkでエスケープ文字を使う場合:  \074: <, \076: >, \077: ?'
cat test-slides.txt |awk '/<\?xml/,/<\/speak>/' > tmp.txt
```

tmp.txtに抽出されたトークスクリプトを分割して、 xml/{1..3}.xml ファイルに保存します

```
cat << EOF   > txt2xml.py
#!/usr/bin/python3
# Usage: python3 txt2xml.py xml_txt

import sys

xml_txt = sys.argv[1]

i = 0
with open(xml_txt, 'r') as f:
    line = f.readline()
    while line:
        if line == '<?xml version="1.0" encoding="UTF-8"?>\n':
        	i+=1
        with open('xml/' + str(int(i)) + '.xml', 'a') as g:
        	print(line, end='', file=g)
        line = f.readline()
EOF
rm -f xml/*
python3 txt2xml.py tmp.txt; rm -f tmp.txt
```

----
### 5. トークスクリプト(xml)からjson, mp3ファイルの作成
1.で作成したlexiconとトークスクリプト(xml)から、スピーチノート付きのjsonファイル, mp3ファイルを作成して、{json,mp3}ディレクトリに保存します。Voice IDは日本語女性(Mizuki)を指定していますが、必要に応じて適宜変更してください。既知の制限として、`aws polly`でxmlファイルを読み込ませる際に、「&」などがそのままだとパースできないというエラーになりますので、ご注意ください。  
(「Q&A対応」などがエラーになります)

```
: '# test という名前でlexiconを保存'
aws polly put-lexicon --name test --content file://test-lexicon.pls

for i in {1..3}; 
do aws polly synthesize-speech \
    --lexicon-names test \
    --text-type ssml \
    --output-format json \
    --voice-id Mizuki \
    --speech-mark-types='["sentence"]' \
    --text file://xml/$i.xml \
    json/$i.json;

  aws polly synthesize-speech \
    --lexicon-names test \
    --text-type ssml \
    --output-format mp3 \
    --voice-id Mizuki \
    --text file://xml/$i.xml \
    mp3/$i.mp3;
done
```

このコマンドで作成されるjsonファイルは ↓ のようになります。  
文章は句読点「。」ごとに自動的に区切られ、各文の読み上げ開始時間がミリ秒単位で[time]に記載されます。

```
cat json/1.json 
{"time":0,"type":"sentence","start":84,"end":193,"value":"これはタイトルスライドであり、\nこれから、サンプルスライドをご紹介します。"}
{"time":5227,"type":"sentence","start":194,"end":259,"value":"OpenShiftとVirtualizationの読み上げテストもします。"}
```

登録したlexiconを削除する場合は、下記を実行してください。

```
aws polly delete-lexicon --name test
aws polly list-lexicons; : '← test という名前のlexiconが削除されたことを確認'
```

Azure Speechを利用する場合は、次の処理を実施しています。

 - slide2mp4の引数として、レキシコンファイルを指定した場合、Amazon S3にレキシコンファイルを一時的にアップロードし、アップロード先のURLを取得
   - レキシコンファイルのURLを指定した場合は、Amazon S3へのレキシコンファイルアップロードを実施しません。
 - Amazon Pollyで利用できるSSMLフォーマットのxmlファイルを、Azure Speechで利用できるようなフォーマットに自動変換
   - この時、文章単位で字幕を挿入するために、文末の「。」「.」「!」「！」「?」「？」、または、2つ以上連続する改行文字ごとに、文章を分割して、複数のxmlファイルを作成
 - 上記の自動変換したxmlファイルを利用し、REST API(curlコマンド)でAzure Speechから音声ファイル(mp3)を取得
 - 文章単位で取得した上記mp3ファイルをもとに、ffprobeで音声再生時間を取得し、各文章の再生時間をもとにjsonファイルを作成
   - 最初の文章は0ミリ秒から開始、2つめの文章の開始時間は最初の文章の再生時間(ミリ秒)、3つめの文章の開始時間は最初の文章と2つめの文章の再生時間を足し算した時間(ミリ秒)...の情報を計算していき、ページ単位でjsonファイルに記載
   - 例えば5ページに3つの文章がある場合、1つめの文章の再生時間が3500ミリ秒、2つめが4730ミリ秒だとすると、jsonファイルは次のようになります。
```
cat json/5.json
{"time":0,"value":"5ページにある、1つめの文章です。"}
{"time":3500,"value":"5ページにある、2つめの文章です。"}
{"time":8230,"value":"5ページにある、3つめの文章です。"}
```
 - 文章ごとに分割した分割したmp3ファイルを結合して保存
   - 上記の例だと、5-{1,2,3}.mp3と、5ページに対して3つの音声ファイルが作成されているため、これを5.mp3に結合して、mp3ディレクトリに保存


----
### 6. jsonファイルからsrtファイルへの変換
jsonファイルからsrtファイルへ変換し、srtディレクトリに保存します。

```
cat << EOF  > json2srt.py
#!/usr/bin/python3
# Usage: python3 json2srt.py polly_output.json srt_file.srt

import json
import os
import sys

def getTimeCode(time_seconds):
	seconds, mseconds = str(time_seconds).split('.')
	mins = int(seconds) / 60
	tseconds = int(seconds) % 60
	return str( "%02d:%02d:%02d,%03d" % (00, mins, tseconds, int(0) ))

json_file = sys.argv[1]
srt_file = sys.argv[2]

i = 0
with open(json_file, 'r') as f:
	line = f.readline()
	while line:
		with open('tmp' + str(i) + '.json', 'w') as g:
			print(line, file=g)
		line = f.readline()
		num = i
		i+=1

timecode = []
message = []
i = 0
while i <= num:
	with open('tmp' + str(i) + '.json', 'r') as f:
		json_load = json.load(f)
		time_seconds1 = float(json_load['time'] / 1000)
		time_seconds2 = time_seconds1 + 1
		timecode.append(getTimeCode(time_seconds1))
		timecode.append(getTimeCode(time_seconds2))
		message.append(json_load['value'])
	os.remove('tmp' + str(i) + '.json')
	i+=1

i = 0
with open(srt_file, 'w') as f:
	if num == 0:
		print(i+1, '\n', '00:00:00,500', ' --> ', timecode[0], '\n', message[i], sep='', file=f)
	else:
		print(i+1, '\n', '00:00:00,500', ' --> ', timecode[i*2+2], '\n', message[i], '\n', sep='', file=f)
		i+=1
		while i <= num:
			if i == num:
				print(i+1, '\n', timecode[i*2+1], ' --> ', timecode[0], '\n', message[i], sep='', file=f)
			else:
				print(i+1, '\n', timecode[i*2+1], ' --> ', timecode[i*2+2], '\n', message[i], '\n', sep='', file=f)
			i+=1
EOF
for i in {1..3}; do python3 json2srt.py json/$i.json srt/$i.srt; done
```

作成されるsrtファイルは、↓ のようになります。  
実は、字幕に振る番号は飾りなので、連番でなくても構いませんが、分かりやすさを優先して連番にしています。  
また、一番最後の字幕で 「--> 00:00:00,000」とすることで、動画再生終了時刻まで字幕が表示されるようになります。

```
$ cat srt/1.srt 
1
00:00:00,500 --> 00:00:05,000
これはタイトルスライドであり、
これから、サンプルスライドをご紹介します。

2
00:00:06,000 --> 00:00:00,000
OpenShiftとVirtualizationの読み上げテストもします。
```

----
### 7. 作成した画像ファイル(png), 音声ファイル(mp3), 字幕ファイル(srt)の合成
3.で作成した画像ファイル(png)と、5.で作成した音声ファイル(mp3)と、6.で作成した字幕ファイル(srt)を合成して、mp4ディレクトリに保存します。 字幕のフォントはNotoSansCJKjp-Mediumの14サイズを指定していますが、これは適宜変更してください。もし、字幕を付けたくない場合は、`-vf`オプションを削除(↓の例だと`-vf "subtitles=srt/$i.srt:force_style='FontName=NotoSansCJKjp-Medium,FontSize=14'"`を削除)して、ffmpegを実行するようにしてください。

```
for i in {1..3}; do ffmpeg -y -loop 1 -i png/image-$i.png -i mp3/$i.mp3 -vcodec libx264 -tune stillimage -pix_fmt yuv420p -shortest -vf "subtitles=srt/$i.srt:force_style='FontName=NotoSansCJKjp-Medium,FontSize=14'" mp4/$i.mp4; done
```

上記コマンドは、ソフトウェアエンコーダ libx264 (`-vcodec libx264`) を指定していますが、ffmpegの[ハードウェアエンコーディング](https://trac.ffmpeg.org/wiki/HWAccelIntro)を利用したい場合は、libx264 より画質が粗くなるので、画像ビットレート (`-vb 1M`など) を明示的に指定する必要があります。その場合、動画のサイズも大きくなりますが、GPUによるエンコーディングが実行されることで、CPUの負荷を減らせます。

```
ffmpeg -encoders |grep -i h264; : '← h264 (mp4) で利用できるencoderを確認'
...<snip>...
 V..... libx264              libx264 H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10 (codec h264)
 V..... libx264rgb           libx264 H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10 RGB (codec h264)
 V..... h264_videotoolbox    VideoToolbox H.264 Encoder (codec h264)   
: '↑ HW encoder: h264_videotoolbox を確認 (M1 Macの場合)'
: '↑ SW encoder: libx264, libx264rgb を確認' 

for i in {1..3}; do ffmpeg -y -loop 1 -i png/image-$i.png -i mp3/$i.mp3 -vcodec h264_videotoolbox -vb 1M -tune stillimage -pix_fmt yuv420p -shortest -vf "subtitles=srt/$i.srt:force_style='FontName=NotoSansCJKjp-Medium,FontSize=14'" mp4/$i.mp4; done
```

使用するマシンによって、利用可能な HW encoder が異なりますので、上記を参考にご確認ください。

----
### 8. 動画ファイルの無劣化結合
分割作成した動画ファイル(mp4/{1..3}.mp4})を無劣化結合します。これにより、test-output.mp4という字幕及び音声付き動画ファイルが作成されます。
結合するmp4ファイルをリスト化したテキストファイルを作成して、それをもとに、`ffmpeg -f concat`で動画を結合します。

Linuxの場合:
```
ls -v mp4/*.mp4 | sed 's/^/file /' > list.txt
```

macOSのzshの場合:
```
rm -f list.txt; for i in {1..3}; do echo "file mp4/$i.mp4" >> list.txt; done
```

動画ファイルの結合:
```
ffmpeg -y -f concat -i list.txt -c copy test-output.mp4
```

----
### 9. 作成した動画ファイルの修正
修正がある場合は、手順 1.に戻ってスライドやトークスクリプトを修正し、再度、手順2.~ 8.を繰り返します。  
この手順2.~ 8.をまとめたスクリプトが、slide2mp4.sh です。

slide2mp4.sh の使い方:
```
slide2mp4.sh [-lexicon LEXICON_FILE/URL] PDF_FILE TXT_FILE OUTPUT_MP4 <"page_num1 page_num2...">
```

末尾のページ番号指定はオプションで、一部のスライドやトークスクリプトを修正して、そこだけjson, srt, mp3, mp4を新しくして動画にパッチを入れたい場合に使います。
既存の mp3, mp4, srt ファイルを使い回すことで、aws polly, ffmpeg の実行時間を短縮できます。
ただし、ページの追加/削除をした場合は、全体的にページ番号が変わるので、全スライドを対象にして、slide2mp4.sh を実行してください。

例. 2, 5, 12 ページのみを修正してDLしたPDF, テキストファイルを利用して、動画にパッチを当てる場合:
```
slide2mp4.sh test01.pdf test01.txt test01-output.mp4 “2 5 12”
```

