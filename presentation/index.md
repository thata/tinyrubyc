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

---

## ✂️ 自己紹介

* はたけやまたかし
* 永和システムマネジメント
* X(Twitter)： @htkymtks

![bg right:50% w:50%](htkymtks.jpg)
<!-- ![bg w:200 right:35% auto](htkymtks.jpg) -->

---

## 🐫 趣味の低レイヤ活動

* CPU自作（TD4, RISC-V）
* RISC-Vシミュレータ自作
* MinCamlコンパイラを移植（RISC-V、ARM64）
* コンパイラ自作（TinyRuby）← NEW!!!

---

<!--
Rubyでコンパイラを作った中で得た経験やコツをお話しします。この話を聞いて、コンパイラ作成や低レイヤな世界に興味を持ってもらえたらうれしいです。

TinyRubyの紹介、コンパイラをさわる中で得たコツをお話し、四則演算を行う簡単なコンパイラの作り方を紹介します
-->

### 🙂 今日話すこと

* TinyRubyの紹介
* コンパイラ作成のTIPS
* コンパイラはじめの一歩

### 🙃 話さないこと

* 字句解析と構文解析
* 最適化
* 型検査

---

# 🦊 コンパイラと私

* 若かりし頃にドラゴンブックで挫折 🐉
* 東大CPU実験を知り、低レイヤに興味を持つ
  * → MinCamlコンパイラを「ARM64」や「RISC-V」へ移植
* 1からコンパイラを作ってみたい気持ちが高まり ← 今ココ👈

---

<!-- 文字を少し小さく -->
<style scoped> section { font-size: 2.3em; } </style>

# 🐇 TinyRuby の紹介

こんな感じのプログラミング言語

```ruby
#
# fib.rb
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

---

## 🐇🐇 TinyRuby のビルドと実行

こんな感じにビルドする

```sh
# コンパイルしてアセンブリを出力
$ ruby tinyrubyc.rb fib.rb > fib.s

# アセンブリをアセンブルして実行ファイルを作成
$ gcc -o fib fib.s libtinyruby.c

# 実行
$ ./fib
55
```

---

<!-- 文字を少し小さく -->
<style scoped> section { font-size: 2.3em; } </style>

# 🤖 TinyRuby と MinRuby

* TinyRuby は MinRubyのサブセット
  * パーサーも MinRuby のものを流用
* MinRuby
  * 「RubyでつくるRuby」に登場するRubyのサブセット言語
  * MinRuby のパーサーは `minruby` ジェムとして提供されている
* MinRuby との差異
  * データ型は整数型のみ
  * ArrayとHashをサポートしない
  * 関数の引数は6つまで

![bg right:35% auto](image-3.png)

---

## 🐧 TinyRubyコンパイラのターゲット環境

* CPU
  * x86-64
* OS
  * Linux

---

# 🍟 コンパイラ作成のTIPS

TinyRuby の作成を通して得たコンパイラ作成のコツを紹介

1) 困ったらCコンパイラに聞く
2) レジスタとABIを知る
3) インクリメンタルな機能実装

---

# :one: 困ったらCコンパイラに聞く

* アセンブリの書き方に悩んだら、Cコンパイラが出力するアセンブリを確認する
* 2つの確認方法
  1) GCCの`-S`オプション
  2) Compiler Explorer

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

---

<!-- 文字を少し小さく -->
<style scoped> section { font-size: 2.3em; } </style>

## 　⚡️ Compiler Explorer ( https://godbolt.org/ )

様々な言語・コンパイラ・CPUのアセンブリ出力を確認できるカッコいいサイト（ドメインもカッコいい）

* C, C++, C#, Go, Rust, Swift, WASM, x86, ARM, RISC-V, MIPS, PowerPC, ...

![CompilerExplorer](image-2.png)

---

# :two: レジスタとABIを知る

コンパイラが出力するアセンブリを理解するためには、対象となるCPUの「レジスタ構成」と「ABI」を知る必要がある

---

<!-- 文字を少し小さく -->
<style scoped> section { font-size: 2.3em; } </style>

## 📝 x86-64 の64ビット汎用レジスタ

x86-64 には、64 ビットの汎用レジスタが 16 本用意されている

* RAX
* RBX
* RCX
* RDX
* RSI
* RDI
* RBP
* RSP
* R8 〜 R15 (x86-64 で追加された8本のレジスタ)

---

<!-- 文字を少し小さく -->
<style scoped> section { font-size: 2.3em; } </style>

## 📝 x86-64 レジスタとビット幅

x86-64では、64ビットレジスタの下位ビットを、32ビットレジスタや16ビットレジスタとして利用できる

* RAXレジスタ（64ビットレジスタ）
* RAXレジスタの下位32ビット → EAXレジスタ（32ビットレジスタ）
* RAXレジスタの下位16ビット → AXレジスタ（16ビットレジスタ）

---

# 🦐 x86-64 のABI (Application Binary Interface)

アセンブリ言語レベルでの関数の呼び出し規約などのこと

* 関数の引数の渡し方
* 関数の戻り値の返し方
* レジスタの使い方のルール

---

<!-- 文字を少し小さく -->
<style scoped> section { font-size: 2.3em; } </style>

#### 🤧 関数の引数の渡し方

* 最初の6つの引数は、RDI, RSI, RDX, RCX, R8, R9 レジスタに渡す
* 7つ目以降の引数は、スタックに積む

#### 🐸 関数の戻り値の返し方

* 戻り値は、RAX レジスタに返す

#### 📝 レジスタの使い方のルール

* RBX, RSP, RBP, R12, R13, R14, R15 レジスタを利用する際は、元の値を退避してから利用して、使い終わったら元の値に戻す
* 他の汎用レジスタは、保存などせず勝手に上書きして良い

---

## 🦀 ABI の詳細資料

x86-64 の ABI の詳細については、以下のドキュメントなどを参照

* System V Application Binary Interface AMD64 Supplement
  * https://refspecs.linuxbase.org/elf/x86-64-abi-0.99.pdf
* こちらは Linux で採用されている ABI で、Windows などでは異なる ABI が採用されている

---

<!-- 文字を少し小さく -->
<style scoped> section { font-size: 2.1em; } </style>

# :three: インクリメンタルな機能実装

* 最初は、入力された整数リテラルを評価するだけのプログラムからスタート
* 1つずつ機能を追加していく
  * 整数リテラル
  * → 四則演算
  * → 変数代入/参照
  * → 複数ステートメント
  * → 比較演算
  * → 条件分岐
  * → 関数呼び出し
  * → 関数定義
  * → ...

---

<!-- 文字を少し小さく -->
<style scoped> section { font-size: 2.3em; } </style>

## 🎲 インクリメンタルな機能実装のメリット

* コンパイラへの理解を徐々に深めることができる
* モチベーションを維持しやすい

#### 参考サイト

* 低レイヤを知りたい人のためのCコンパイラ作成入門 https://www.sigbus.info/compilerbook
* An Incremental Approach to Compiler Construction http://scheme2006.cs.uchicago.edu/11-ghuloum.pdf

---

# :walking: コンパイラはじめの一歩

これまで紹介したTIPSを使って、整数を評価して返すだけの TinyRuby コンパイラを作ってみます

* 既存の言語のパーサを利用
* 困ったらCコンパイラに聞く
* インクリメンタルな機能実装

---

## 💯 「整数を評価して終了ステータスとして返すだけのコンパイラ」を作成する

###### プログラム (test1.rb)
```ruby
123
```

###### 期待する動作

```sh
# 終了ステータスに 123 が返る
$ ./test1
$ echo $?
123
```

---

## 💯 整数リテラルをパース
MinRubyパーサで整数リテラルをパースすると、以下のような構文木が得られる
```ruby
irb(main):001> require 'minruby'
=> true
irb(main):002> minruby_parse '123'
=> ["lit", 123]
irb(main):003> minruby_parse '456'
=> ["lit", 456]
```

* ０番目の要素: "lit"
* １番目の要素: 整数リテラルの値

---

## 💯 Cコンパイラでアセンブリを出力

TinyRubyコンパイラが出力するアセンブリのイメージを掴むため、C言語で同じプログラムを書いて、GCCでアセンブリを出力してみる

```c
int main() {
  return 123;
}
```

上記のプログラムのアセンブリを出力

```sh
$ gcc -S -masm=intel -fno-asynchronous-unwind-tables test1.c
```

---

### 💯 出力されたアセンブリコード

```asm
	.intel_syntax noprefix
	.text
	.globl	main
	.type	main, @function
main:
	;; 関数プロローグ
	push	rbp
	mov	rbp, rsp

	;; 戻り値 123 を EAX レジスタにセット
	;; * 関数の戻り値は RAX レジスタにセットされる
	;; * EAX レジスタは、RAX レジスタの下位32ビットを表す
	mov	eax, 123

	;; 関数エピローグ
	pop	rbp

	;; 関数から戻る
	ret
```

---

#### 💯 整数を評価して返すだけのTinyRubyコンパイラ

```ruby
# trc.rb
require 'minruby'

def gen(node)
  case node[0]
  when "lit"
    puts "  mov rax, #{node[1]}"
  end
end

node = minruby_parse(ARGF.read)

puts "  .intel_syntax noprefix"
puts "  .text"
puts "  .globl main"
puts "main:"
puts "  push rbp"
puts "  mov rbp, rsp"

gen(node)

puts "  pop rbp"
puts "  ret"
puts "  .section .note.GNU-stack,\"\",@progbits"
```

---

<!-- コンパイルして、実行 -->

```sh
$ echo "123" | ruby trc.rb
  .intel_syntax noprefix
  .text
  .globl main
main:
  push rbp
  mov rbp, rsp
  mov rax, 123
  pop rbp
  ret
  .section .note.GNU-stack,"",@progbits
```

```sh
$ echo "123" | ruby trc.rb > return123.s
$ gcc -o return123 return123.s
$ ./return123
$ echo $?
123
```

---

（明日はここから/四則演算？）

---

# 🏯 まとめ

* コンパイラ作成のTIPSの紹介
  * 困ったらCコンパイラに聞く
  * レジスタとABIを知る
  * インクリメンタルな機能実装
* コンパイラを通して低レイヤの世界にふれてみよう！
