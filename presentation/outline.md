---
marp: true
theme: default
class: lead
style:
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

# 話すこと

* コンパイラと私
* TinyRubyについて
* コンパイラ作成寺のテクニック
* コンパイラ開発の具体例

---

# 話さないこと

* 字句解析と構文解析
* 最適化
* 型検査

---

# コンパイラと私

* MinCamlコンパイラを移植
  * AArch64（Apple M1）
  * RISC-V
* 1からコンパイラを作りたい！

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

# TinyRubyのサンプル

```ruby
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

# TinyRubyコンパイラのターゲット環境

* CPU
  * x86_64
* OS
  * Linux

（手元のパソコンがApple M1なMacなので、Docker上のLinuxで動作確認してます）

---

# コンパイラ作成のコツ

* 既存の言語のパーサを使おう
* 困ったらCコンパイラに聞く
* インクリメンタルな機能実装
* レジスタとABIを知る
* スタックフレームを理解する（オプション）

---

# 既存の言語のパーサを使おう （言語処理系の入門者の場合）
* ハードルが高く挫折しやすい
  * 言語の設計
  * 構文解析器（パーサ）の実装
* 既存のパーサを使うことで、コンパイラの実装に集中できる

---

# 困ったらCコンパイラに聞く

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

# インクリメンタルな機能実装

* 最初は、入力された整数リテラルを評価するだけのプログラムからスタート
* 1つずつ機能を追加していく
  * 整数リテラル
  * 四則演算
  * 変数代入
  * 変数参照
  * 複数ステートメント
  * 比較演算
  * 条件分岐
  * 関数呼び出し
  * 関数定義

---

# コンパイラはじめの一歩

* 既存の言語のパーサを利用
* 困ったらCコンパイラに聞く
* インクリメンタルな機能実装

上記の実例として、整数を評価するだけの TinyRuby コンパイラを作成してみます

---

# 既存の言語パーサを利用

* MinRuby パーサの使い方
* MinRuby パーサが返す構文木
* 構文木とは？

---




