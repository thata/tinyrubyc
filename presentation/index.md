---
marp: true
theme: default
class: lead
paginate: true
backgroundColor: #fff
backgroundImage: url('https://marp.app/assets/hero-background.svg')
---

# Building a Ruby-like language compiler in Ruby

## RubyでつくるRubyみたいな言語のコンパイラ

はたけやまたかし（@htkymtks）
株式会社 永和システムマネジメント

---

# 自己紹介

* はたけやまたかし
* 永和システムマネジメント
* 低レイヤが趣味
  * CPU自作
  * RISC-Vシミュレータ自作
  * MinCamlコンパイラを移植（RISC-V、ARM64）

---

## 今日話すこと

* コンパイラと私
* TinyRubyについて
* コンパイラ作成寺のテクニック
* コンパイラ開発の具体例

## 話さないこと

* 字句解析と構文解析
* 最適化
* 型検査

---

# コンパイラと私

* MinCamlコンパイラを移植
  * AArch64（Apple M1）
  * RISC-V
* 1からコンパイラを作りたい

---
# TinyRubyについて

* TinyRuby
  * MinRubyのサブセット
* MinRuby
  * Rubyのサブセット
  * 「RubyでつくるRuby」に登場
  * https://www.lambdanote.com/products/ruby-ruby
* MinRubyとの差異
  * データ型は整数のみ
  * ArrayとHashは無し
  * 関数の引数は6つまで

![bg right auto](image-3.png)

---

# TinyRubyはこんな言語

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

## fib.rb をコンパイルして実行

```:sh
# fib.rb をコンパイル
$ ruby tinyrubyc.rb fib.rb > fib.s

# fib.s をアセンブル
$ ./docker-run.sh gcc -o fib fib.s libtinyruby.c

# 実行ファイル fib を実行
$ ./docker-run.sh ./fib
55
```

---

# TinyRubyコンパイラのターゲット環境

* CPU
  * x86-64
* OS
  * Linux

（手元のパソコンがApple M1なMacなので、Docker上のLinuxで動作確認してます）

---

# コンパイラ作成 5つのコツ

1. 既存の言語のパーサを使おう
2. 困ったらCコンパイラに聞く
3. インクリメンタルな機能実装
4. レジスタとABIを知る

---

# (1) 既存の言語のパーサを使おう
* ハードルが高く挫折しやすい
  * 言語の設計
  * 構文解析器（パーサ）の実装
* 既存のパーサを使うことで、コンパイラの実装に集中できる

---

# (2) 困ったらCコンパイラに聞く

* アセンブリの書き方に悩んだら、Cコンパイラが出力するアセンブリを確認する
* 2つの確認方法
  * GCCの`-S`オプション
  * Compiler Explorer

---

# GCCの `-S` オプション

GCC の `-S` オプションで、Cからアセンブリを出力できる

```c
// test.c
int return_100() {
  return 100;
}
```

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

# Compiler Explorer ( https://godbolt.org/ )

様々な言語・コンパイラ・CPUのアセンブリ出力を確認できるウェブサイト

* C, C++, C#, Go, Rust, Swift, WASM, x86, ARM, RISC-V, MIPS, PowerPC, ...

![CompilerExplorer](image-2.png)

---

# (3) インクリメンタルな機能実装

* 最初は、入力された整数リテラルを評価するだけのプログラムからスタート
* 1つずつ機能を追加していく
  * 整数リテラル → 四則演算 → 変数代入/参照 → 複数ステートメント → 比較演算 → 条件分岐 → 関数呼び出し → 関数定義 → ...

---

# インクリメンタルな機能実装のメリット

* 簡単な機能から段階的に機能を追加していくことで、コンパイラへの理解を徐々に深めていくことができる
* モチベーションの維持

##### 参考

* 低レイヤを知りたい人のためのCコンパイラ作成入門 https://www.sigbus.info/compilerbook
* An Incremental Approach to Compiler Construction http://scheme2006.cs.uchicago.edu/11-ghuloum.pdf


---

# (4) レジスタとABIを知る

コンパイラが出力するアセンブリを理解するためには、対象となるCPUの「レジスタ構成」と「ABI」を知る必要がある

---

# x86-64 の64ビット汎用レジスタ

x86-64 は64ビットの汎用レジスタが16本用意されている

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

# x86-64 レジスタとビット幅

x86-64では、64ビットレジスタの下位ビットを、32ビットレジスタや16ビットレジスタとして利用できる

* RAXレジスタ（64ビットレジスタ）
* RAXレジスタの下位32ビット → EAXレジスタ（32ビットレジスタ）
* RAXレジスタの下位16ビット → AXレジスタ（16ビットレジスタ）

---

# x86-64 のABI (Application Binary Interface)

アセンブリ言語レベルでの関数の呼び出し規約などのこと

* 関数の引数の渡し方
* 関数の戻り値の返し方
* レジスタの使い方のルール

---

## 関数の引数の渡し方

* 最初の6つの引数は、RDI, RSI, RDX, RCX, R8, R9 レジスタに渡す
* 7つ目以降の引数は、スタックに積む

## 関数の戻り値の返し方

* 戻り値は、RAX レジスタに返す

## レジスタの使い方のルール

* RBX, RSP, RBP, R12, R13, R14, R15 レジスタを利用する際は、元の値を退避してから利用して、使い終わったら元の値に戻す
* 他の汎用レジスタは、保存などせず勝手に上書きして良い

---

## ABI の詳細資料

x86-64  の ABI の詳細については、以下のドキュメントなどを参照

* System V Application Binary Interface AMD64 Supplement
* https://refspecs.linuxbase.org/elf/x86-64-abi-0.99.pdf


---

# コンパイラはじめの一歩

これまで紹介したテクニックを使って、整数を評価して返すだけの TinyRuby コンパイラを作ってみます

* 既存の言語のパーサを利用
* 困ったらCコンパイラに聞く
* インクリメンタルな機能実装

---

# 既存の言語パーサを利用

* MinRuby パーサの使い方
* MinRuby パーサが返す構文木
* 構文木とは？

---

# まとめ

* コンパイラ作成のテクニックの紹介
  * 既存の言語のパーサを使おう
  * 困ったらCコンパイラに聞く
  * インクリメンタルな機能実装
  * レジスタとABIを知る
* コンパイラを通して低レイヤの世界にふれてみよう！
