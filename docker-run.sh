#!/bin/bash

docker run --rm -it -v $PWD:/app -w /app --platform=linux/amd64 tinyruby-dev "$@"

