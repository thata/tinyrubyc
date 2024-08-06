Rubyで書かれた、Rubyのサブセット言語「TinyRuby」のコンパイラ。x86_64/Linux向けのアセンブリコードを出力します。

# Usage

事前に `minruby` gem をインストールしておく

```sh
gem install minruby
```

`fib.rb` をコンパイルして x86_64 のアセンブリを出力する

```sh
ruby tinyrubyc.rb fib.rb > tmp.s
```

出力したアセンブリを x86_64/Linux の Docker コンテナ上でコンパイルして実行する

```sh
$ docker run --rm -it -v $PWD:/app -w /app --platform=linux/amd64 gcc bash
$ gcc -z noexecstack tmp.s libtinyruby.c
$ ./a.out
55
$
```

# Run tests

以下のコマンドでテストスクリプトを実行する
```sh
./test.sh
```
