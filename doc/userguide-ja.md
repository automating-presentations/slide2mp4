# slide2mp4 のユーザーガイド 

slide2mp4 による動画作成の仕組みを紹介します。  
slide2mp4.sh の中で宣言してある変数の変更などは、本ガイドを参考にしてください。

----
## テストデータの利用方法

[システム要件](https://github.com/h-kojima/slide2mp4#requirements)を満たしている場合、テストデータを利用したテストを実行できます。slide2mp4.sh では字幕のデフォルトフォントを「NotoSansCJKjp-Medium, 14サイズ」と指定しています。フォントが無い場合はシステムデフォルトのフォントが使われると思いますが、その場合は、slide2mp4.sh のフォントに関する変数を適宜変更してください。

```
git clone https://github.com/h-kojima/slide2mp4
chmod u+x slide2mp4/slide2mp4.sh
cd slide2mp4/test
../slide2mp4.sh test-slides.pdf test-slides.txt test-lexicon.pls test-output.mp4
```

----
## 入力ファイルと出力ファイル

入力ファイル:
 - Google Slides
   - Google SlidesからDLした、PDFとPlain Textファイルが必要
   - Google Slidesでは、スピーカーノートを一括保存可能。スライド左上メニューの [File] -> [Download] -> [Plain Text] により、
     スライドとスピーカーノートのテキスト部分が 1つのテキストファイルにまとめられたものをDL可能
   - PDFのDL時にフォントが崩れる場合は、一度pptxでDLした後に、PowerPointを開いてPDF Export
   - LibreOfficeを利用している場合は、pptx形式で保存した後に、Google DriveにアップロードしてGoogle Slidesでpptxファイルを開くと、上記と同様にスピーカーノートの一括保存が可能
 - SSML情報を含んだXMLで書かれたトークスクリプト (Google Slidesのスピーカーノート内に記載)
 - 発音エイリアスを記載した[lexicon](https://docs.aws.amazon.com/ja_jp/polly/latest/dg/managing-lexicons.html)
   - 日本語音声だと、英字の製品名をうまく読んでくれない時があるので、予めエイリアスを記載したファイルを作成しておく必要あり

出力ファイル:
 - PDFから変換した画像ファイル (png)
 - 音声ファイル (mp3)
 - スピーチマーク(タイプスタンプ)付きのトークスクリプトファイル (json)
 - 字幕ファイル (srt)
 - 動画ファイル (音声と字幕付き. mp4)

----
## 720pの紹介動画の作り方(テストガイド)

トークスクリプト込みのスライド作成方法と、slide2mp4.sh の実行処理の流れを順にご紹介します。

### 1. Google Slidesを作成
スライド作成時に、test.xmlのような形式でトークスクリプトをスライドノート内に記載します。  
なお、一文(一文の終了は句読点の「。」)の中の改行も字幕に反映されるので、区切りたいポイントで改行をしておきます。  
本ガイドでの手順により、一文ごとに1つの字幕が表示されます。一文が長くなり、3行や4行とかになると、スライドの文字が見にくくなりますので、スライドの情報量にもよりますが、一文は2行程度に抑えておくと、字幕が見やすくなります。

```
cat << EOF  > test.xml
<?xml version="1.0" encoding="UTF-8"?>
<speak version="1.1"> 

<prosody rate="110%">
これはタイトルスライドです。
これから、サンプルスライドをご紹介します。
</prosody>

</speak>
EOF
```

このtest.xmlでは、[機械音声の読み上げ速度](https://docs.aws.amazon.com/ja_jp/polly/latest/dg/voice-speed-vip.html)を110%にしています。  
これは適宜変更してください。  
スライド作成後は、PDFとPlain Textファイルをダウンロードします。

また、英字の製品名などで機械音声でうまく読み上げられないものについては、予めlexiconを利用して発音のエイリアスを作っておきます。
↓ では、OpenShiftとVirtualizationの発音エイリアスを登録しています。

```
cat << EOF  > test-lexicon.pls
<?xml version="1.0" encoding="UTF-8"?>
<lexicon version="1.0"
      xmlns="http://www.w3.org/2005/01/pronunciation-lexicon"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.w3.org/2005/01/pronunciation-lexicon
        http://www.w3.org/TR/2007/CR-pronunciation-lexicon-20071212/pls.xsd"
      alphabet="ipa" xml:lang="ja-JP">

  <lexeme> 
    <grapheme>Virtualization</grapheme>
    <alias>バーチャライゼーション</alias>
  </lexeme>

  <lexeme> 
    <grapheme>OpenShift</grapheme>
    <grapheme>openshift</grapheme>
    <alias>オープンシフト</alias>
  </lexeme>

</lexicon>
EOF

# test という名前でlexiconを保存
aws polly put-lexicon --name test --content file://test-lexicon.pls
```

登録した lexiconを削除する場合は、下記を実行してください。

```
aws polly delete-lexicon --name test
aws polly list-lexicons    ← test lexiconが削除されたことを確認
```

### 2. json/mp3/mp4/png/srt/xml ファイルを保存するディレクトリを作成
```
mkdir -p json mp3 mp4 png srt xml
```

### 3. PDFファイルからpngファイルへの一括変換
最初の手順で作成した、複数ページのPDFファイル(test-slides.pdf)を次のコマンドで複数の720pのpngファイルに一括変換します。この例では、3ページのPDFファイルをpng/{1..3}.pngに変換します。
解像度を1080p(1920x1080)にする場合は、geometryを 1920x1080 に変更します。

```
rm -f png/*
gm convert -density 300 -geometry 1280x720 +adjoin test-slides.pdf png:png/%01d-tmp.png
for i in {0..2}; do mv png/$i-tmp.png png/$(($i+1)).png; done
```

### 4. トークスクリプトをxmlファイルに変換

Google SlidesからPlain Text形式でDLしたtest-slides.txtに含まれる、トークスクリプト(xml)部分を抽出します。スクリプト部分である「 <?xml」から始まり「</speak>」で終わる文字列」を抽出します。  
注: awkの記号エスケープ  \074: <, \076: >, \077: ?

```
cat test-slides.txt |awk '/\<\?xml/,/\<\/speak\>/' > tmp.txt
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
ls xml/
1.xml 2.xml 3.xml
```

