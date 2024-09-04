---

marp: true
paginate: true
theme: gaia
class:
  - invert

---

<!-- _class: lead invert -->

# 👷🏗️ Building a "Ruby-like Language" Compiler in Ruby

## RubyでつくるRubyみたいな言語のコンパイラ

Fukuoka RubyistKaigi 04
2024.09.07
@htkymtks

<!--
今日は、Rubyみたいな言語のコンパイラをRubyで作ったお話と、その中で得た経験やコツについてお話ししようと思います。
-->

---

## 🚕💥🚗 自己紹介

- はたけやまたかし
- 株式会社永和システムマネジメント
  ![w:300](esm.png)
- Twitter(現X)： @htkymtks
  ![w:600](twitter.png)

<!--
まず自己紹介です。
はたけやまたかしと申します。株式会社永和システムマネジメントという会社で、Rubyプログラマとして働いています。
Twitter（現X）ではこちらのアカウントで、主にダジャレをつぶやいて暮らしています。
-->

---

<style scoped> section { font-size: 1.8em; } </style>

## 🐫 趣味の低レイヤプログラミング

- 東大CPU実験がきっかけ
  - CPU自作（TD4, RISC-V）
  - RISC-Vシミュレータ自作
  - MinCamlコンパイラを移植（RISC-V、ARM64）
- コンパイラ作成（TinyRuby） ← NEW!!!

![h:250](https://i.gyazo.com/thumb_dpr/1000/9a5a58a043f8a32c011b73e1abb38283-png.png) ![h:250](https://cdn-ak.f.st-hatena.com/images/fotolife/h/htkymtks/20220608/20220608172032.png) ![h:250](https://i.gyazo.com/8c5f6f3f69b1265a9d4fc3255d2a09b5.png)

<!--
自己紹介の続きになるのですが、趣味で低レイヤプログラミングをしています。

東京大学のCPU実験という、CPUを自作したり、自作CPU向けにコンパイラを移植したり、そのCPUの上でレイトレーシングを動かしたりする授業があります。

それに触発されて、私もCPUを自作したり、RISC-Vシミュレータを自作したり、CPU実験で使用するMinCamlという言語のコンパイラを移植したり、という一人CPU実験を趣味で行なっています。

その、MinCamlというコンパイラの移植を行う中で、移植ではなく1からコンパイラを作ってみたいという気持ちが高まりまして、今日お話しするTinyRubyというコンパイラを作成することになりました。
-->

---

### 🙂 今日話すこと

- TinyRubyの紹介
- コンパイラ作成のTIPS
- コンパイラはじめの一歩

<!--
今日お話しすることは、
- TinyRubyの紹介
- TinyRubyの作成を通して得たコンパイラ作成のコツ、TIPSについて
- コンパイラはじめの一歩」ということで、実際にコンパイラを作成する最初の過程をお見せしようと思います
-->

---

<style scoped> section { font-size: 2.0em; } </style>

# 🐇 TinyRuby の紹介

こんな感じのRubyみたいなプログラミング言語

```ruby
#
# fibonacci.rb
#

def fib(n)
  if n < 2
    n
  else
    fib(n-1) + fib(n-2)
  end
end

# 10番目のフィボナッチ数を計算
p fib(10)
```

<!--
さっそく TinyRuby についてご紹介します。TinyRubyは、こんな感じのRubyみたいなプログラミング言語になります。
こちらは10番目のフィボナッチ数の計算をするTinyRubyのプログラムです。
-->

---

## 🐇🐇 TinyRuby のビルドと実行

こんな感じにビルドする

```sh
# コンパイルしてアセンブリを出力
$ ruby tinyrubyc.rb fibonacci.rb > fibonacci.s

# アセンブリをアセンブルして実行ファイルを作成
$ gcc -o fibonacci fibonacci.s libtinyruby.c

# 実行
$ ./fibonacci
55
```

<!--
TinyRuby で書いたプログラムのビルド手順はこんな感じです。

まず、TinyRubyコンパイラで fibonacci.rb をコンパイルしてアセンブリを出力、
次に、出力されたアセンブリを gcc に渡してアセンブルとリンクを行い、実行ファイルを作成します。

最後に、作成した実行ファイルを実行すると、10番目のフィボナッチ数の 55 が画面に出力されます。
-->

---

<style scoped> section { font-size: 1.8em; } </style>

# 🤖 TinyRuby と MinRuby

- TinyRuby は MinRuby のサブセット
- MinRuby
  - 書籍「RubyでつくるRuby」に登場するRubyのサブセット
  - TinyRubyは MinRuby のパーサを利用
- MinRuby との差異
  - データ型は整数型のみ
  - ArrayとHashをサポートしない
  - 関数の引数は6つまで

![bg w:350 right:30% auto](image-3.png)

<!--
さきほど、「TinyRuby は Ruby みたいな言語」と言いましたが、もう少し具体的に言うと、TinyRuby は MinRuby のサブセットになります。

MinRuby は何かというと、「RubyでつくるRuby」という書籍に登場する Ruby のサブセット言語です。この MinRuby のパーサは RubyGems として提供されていて、TinyRuby ではこの MinRuby のパーサをそのまま利用しています。

じゃあ、TinyRuby と MinRuby は何が違うのかと言うと、
・「TinyRuby はデータ型が整数型のみ」
・「Array や Hash をサポートしない」
・「関数の引数が6つまで」
など、いくつかの制限があります。
-->

---

## 🐧 TinyRubyコンパイラのターゲット環境

- CPU
  - x86-64
- OS
  - Linux

<!--
TinyRubyコンパイラのターゲット環境は、CPUが x86-64 で、OSが Linux となります。
私の手元のパソコンは M1 Mac で x86-64 でも Linux でもないので、Docker で仮想環境を作って開発しています。
-->

---

# 🍟 コンパイラ作成のTIPS

1) Cコンパイラが出力するアセンブリコードを活用
2) レジスタとABIを知る
3) テスト駆動コンパイラ開発

<!--
TinyRuby についての紹介はここまでにして、次は、TinyRuby の作成を通して得た、コンパイラ作成時に使えるTIPS、便利情報を紹介します。

1) Cコンパイラが出力するアセンブリコードの活用
2) レジスタとABIを知る
3) テスト駆動コンパイラ開発
-->

---

# :one: Cコンパイラが出力するアセンブリコードを活用

アセンブリの書き方に悩んだら、Cコンパイラが出力するアセンブリを確認する

* 2つの確認方法
  * (1) GCCの`-S`オプション
  * (2) Compiler Explorer

<!--
ひとつ目のTIPSは、アセンブリの書き方に悩んだら、Cコンパイラが出力するアセンブリを確認すると良いです。

私は今回 x86 のアセンブリをはじめて書いたのですが、Cコンパイラの出力するコードを参考にすることで、特につまづくことなく x86 アセンブリを出力するコンパイラを作成することができました。

Cコンパイラが出力するアセンブリを確認する方法は、以下の2つがおすすめです。
1つは、gcc の「ハイフンS」オプションを使う方法
もう1つ、Compiler Explorer というサイトを使う方法です。
-->

---

## 🐃 GCCの `-S` オプション

GCC の `-S` オプションで、Cからアセンブリを出力できる

```c
// test.c
int return_100() {
  return 100;
}
```

```sh
$ gcc -S -masm=intel test.c
```

<!--
まずは GCC の「ハイフンS」オプションを使う方法を紹介します。

通常、GCCにC言語のソースコードを渡すと、コンパイルとアセンブリが行われて、実行ファイルが作成されたり、オブジェクトファイルが作成されたりします。

ここで gcc に「ハイフンS」オプションをつけることで、コンパイルだけを行って、コンパイル結果をアセンブリファイルとして出力することができます。

例えば、こんな感じのC言語のソースコードを、「ハイフンS」オプションをつけて実行すると...（次のページ）
-->

---

## 🐃🐃 GCCの `-S` オプション

出力されたアセンブリコード

```sh
$ gcc -S -masm=intel test.c
$ cat test.s
	.intel_syntax noprefix
	.text
	.globl	return_100
	.type	return_100, @function
return_100:
	push	rbp
	mov	rbp, rsp
	mov	eax, 100
	pop	rbp
	ret
```

<!--
こんな感じにアセンブリコードが出力されます。

ちなみに、アセンブリの出力形式には「インテル形式」と「AT&T形式」とふたつの流派があります。ここではインテル形式で出力するために「-masm=intel」オプションをつけています。
-->

---

<style scoped> section { font-size: 2.0em; } </style>

## 　⚡️ Compiler Explorer ( https://godbolt.org/ )

様々な言語・コンパイラ・CPUのアセンブリ出力を確認できるサイト

![h:450](godbolt.png)

<!--
https://godbolt.org/

もう1つの方法は、Compiler Explorer というサイトを使う方法です。

Compiler Explorer は、様々な言語、コンパイラ、CPUのアセンブリや中間形式の出力を確認できるカッコいいサイトです。

Compiler Explorer の画面は2つの領域に分かれていて、左側にはソースプログラムを書くと、右側にそのソースのアセンブリが出力されます。

ソースプログラムのどの部分が、アセンブリコードのどの部分に対応しているかが、色によってわかりやすく表示されるので、アセンブリの理解に役立ちます。

二つの使い分けについてですが、出力したアセンブリをそのまま実行したい場合はGCCから出力したアセンブリを利用して、「Cのこういうコードはアセンブリだとどう書くんだろう？」というのを確認したい場合は Compiler Explorer を使うのがおすすめです。
-->

---

# :two: レジスタとABIを知る

コンパイラが出力するアセンブリを理解するためには、対象となるCPUの「レジスタ構成」と「ABI」を知る必要がある

<!--
二つめのTIPSは「レジスタとABIを知る」です。

コンパイラが出力するアセンブリを理解するためには、対象となるCPUの「レジスタ構成」と「ABI」を知る必要があります。
-->

---

<style scoped> section { font-size: 1.5em; }</style>

### 📝 汎用レジスタ一覧

x86-64 の 16 本の 64 ビット汎用レジスタ

<table>
  <thead><th>レジスタ名</th><th>用途</th><th>レジスタ名</th><th>用途</th></thead>
  <tbody>
    <tr><td>RAX</td><td>関数の戻り値など</td><td>R8</td><td>関数の第五引数など</td></tr>
    <tr><td>RBX</td><td></td><td>R9</td><td>関数の第六引数など</td></tr>
    <tr><td>RCX</td><td>関数の第四引数など</td><td>R10</td><td>一時データ置き場</td></tr>
    <tr><td>RDX</td><td>関数の第三引数など</td><td>R11</td><td>一時データ置き場</td></tr>
    <tr><td>RSI</td><td>関数の第二引数など</td><td>R12</td><td></td></tr>
    <tr><td>RDI</td><td>関数の第一引数など</td><td>R13</td><td></td></tr>
    <tr><td>RBP</td><td>ベースポインタ</td><td>R14</td><td></td></tr>
    <tr><td>RSP</td><td>スタックポインタ</td><td>R15</td><td></td></tr>
  </tbody>
</table>

<!--
まずレジスタについて説明します。

CPUには「レジスタ」と呼ばれるデータの記憶領域があり、CPUが演算を行う際に利用されたり、一時的なデータの置き場として使用されたりします。

レジスタの構成はCPUごとに異なるため、対象となるCPUのレジスタ構成を理解することは、アセンブリを書くうえで重要になります。

x86-64 では、ここに示す 16 本の 64 ビット汎用レジスタがあります。

汎用レジスタという名前の通り、レジスタの使い道には制限がありませんが、RSPレジスタはスタックポインタとして利用されたり、RAX レジスタは関数の戻り値を返すために使われたりと、ある程度決められた用途があります。

また、これ以外にも浮動小数点数用のレジスタや、フラグレジスタなるものがあったりしますが、ここでは省略します。
-->

---

# 🦐 x86-64 のABI (Application Binary Interface)

アセンブリ言語レベルでの関数の呼び出し規約などのこと

<!--
次に、ABI についてお話しします。

ABI とは、Application Binary Interface の略で、アセンブリ言語レベルでの関数の呼び出しなどの規約のことです。
-->

---

## 🤧 関数の引数の渡し方

* 最初の6つの引数は、RDI, RSI, RDX, RCX, R8, R9 レジスタに渡す
* 7つ目以降の引数は、スタックに積む

## 🐸 関数の戻り値の返し方

* 戻り値は、RAX レジスタに返す

<!--
例えば、関数を呼び出す際には、第一引数はRDIレジスタに、第二引数はRSIレジスタに、といったように、決められたレジスタに引数の値を渡します。また、第七引数以降はスタックに引数の値を積みます。

さらに、関数の戻り値はRAXレジスタに返す、ということがABIで決められています。

ABI でこうした規約を定義することで、規約に従ったモジュール間での関数呼び出しやデータの連携ができるようになります。
-->

---

## 🦀 ABI の詳細資料

x86-64 の ABI の詳細については、以下のドキュメントなどを参照

* System V Application Binary Interface AMD64 Supplement
  * https://refspecs.linuxbase.org/elf/x86-64-abi-0.99.pdf

<!--
ABI のより詳細な情報については、こちらの「System V Application Binary Interface AMD64 Supplement」などを参照してください。

また、これは x86-64 上で動作する Linux の ABI なので、他の OS、他の CPU の場合は、対象となる環境の ABI を調べる必要があります。
-->

---

<style scoped> section { font-size: 2.0em; } </style>

# :three: テスト駆動コンパイラ開発

- An Incremental Approach to Compiler Construction
  - http://scheme2006.cs.uchicago.edu/11-ghuloum.pdf
  - TDDでコンパイラを作成するアプローチ
  - 「低レイヤを知りたい人のためのCコンパイラ作成入門」はこの論文から着想を得ている
- 1つずつ機能を追加していく
  - 整数リテラル → 四則演算 → 変数代入/参照 → 複数ステートメント → 比較演算 → 条件分岐 → 関数呼び出し → 関数定義 → ...

<!--
「An Incremental Approach to Compiler Construction」という論文で紹介されている「TDDでコンパイラを開発しよう！」というアプローチです。

植山類さんが書かれた「低レイヤを知りたい人のためのCコンパイラ作成入門」で紹介されていた論文で、「低レイヤを知りたい人のためのCコンパイラ作成入門」はこの論文から着想を得たそうです。

最初は整数リテラルを評価するところからスタートして、四則演算、変数代入、変数参照、と機能をしていきます。
-->

---

<style scoped> section { font-size: 2.0em; } </style>

## :hand: テストスクリプト(test.sh)

```test.sh
# 整数リテラル
assert 4649 'p 4649'

# 四則演算
assert 20 'p 10 + 20 - 30 * 4 / 12'
assert 60 'p 10 + 20 + 30'
assert 40 'p 30 + 20 - 10'
assert 200 'p 10 * 20'
assert 33 'p 99 / 3'

# 複文
assert 4649 '1 + 1; p 4649'

# 変数
assert 10 'a = 10; p a'
assert 30 'a = 10; b = 20; p a + b'
```

<!--
（あとで書く）
-->

---

<style scoped> section { font-size: 1.9em; } </style>

## 🇮🇹 テスト駆動コンパイラ開発のメリット

- テスト駆動開発の一般的なメリット
  - 即時フィードバック
  - デバッグコストの軽減
  - 必要な機能からひとつずつ実装していくことで「考えすぎ」「やりすぎ」を防ぐ
  - 短いサイクルで達成感を得られるため、モチベーションを維持しやすい
- コンパイラ開発に必要な知識を段階的に習得できる
  - 挫折しづらい

<!--
（あとで書く）
-->

---

<!-- _class: lead invert -->

# :walking: コンパイラはじめの一歩

これまで紹介したTIPSを使って、整数を評価して返すだけの TinyRuby コンパイラを作ってみます

---

<!-- _class: lead invert -->

# 🎬 動画スタート

<video src="TinyRubyDemo.mp4"   width="800" controls></video>

---

# 🍜 まとめ

- TinyRuby の紹介
- コンパイラ作成のTIPSの紹介
  - Cコンパイラが出力するアセンブリコードの活用
  - レジスタとABIを知る
  - テスト駆動コンパイラ開発
- コンパイラを通して低レイヤの世界にふれてみよう！

---

# :three: :five: 参考資料

- 低レイヤを知りたい人のためのCコンパイラ作成入門
  - https://www.sigbus.info/compilerbook
- An Incremental Approach to Compiler Construction
  - http://scheme2006.cs.uchicago.edu/11-ghuloum.pdf
- 保守しやすく変化に強いソフトウェアを支える柱　自動テストとテスト駆動開発⁠⁠、その全体像
  - https://gihyo.jp/article/2024/01/automated-test-and-tdd

