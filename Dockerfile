# usage:
#   cd ~/src/tinyrubyc
#   docker build --platform=linux/amd64 -t tinyruby-dev .
#   docker run --rm -it tinyruby-dev bash

# ベースイメージとしてRubyの公式イメージを指定
FROM ruby:3.3

# 作業ディレクトリを設定
WORKDIR /app

RUN apt update
RUN apt-get install vim -y
RUN gem install minruby
