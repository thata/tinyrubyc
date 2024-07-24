require 'minruby'

# 受け取った構文木からアセンブリコードを生成する
def gen(node)
  if node[0] == "lit"
    # 整数の場合
    # 例 : node = ["lit", 123]
    puts "  mov rax, #{node[1]}"
  elsif %w(+ - * /).include?(node[0])
    # 四則演算の場合
    # 例 : node = ["+", ["lit", 1], ["lit", 2]]

    # r12 と r13 の値をスタックへ退避
    puts "  push r12"
    puts "  push r13"

    # 左辺の計算結果を r12 へ格納
    gen(node[1])
    puts "  mov r12, rax"

    # 右辺の計算結果を r13 へ格納
    gen(node[2])
    puts "  mov r13, rax"

    # 演算結果を rax へ格納
    case node[0]
    when "+"
      puts "  add r12, r13"
      puts "  mov rax, r12"
    when "-"
      puts "  sub r12, r13"
      puts "  mov rax, r12"
    when "*"
      puts "  imul r12, r13"
      puts "  mov rax, r12"
    when "/"
      puts "  mov rax, r12"
      puts "  cqo"
      puts "  idiv r13"
    end

    # r12 と r13 の値をスタックから復元
    puts "  pop r13"
    puts "  pop r12"
  end
end

# 入力をパースする
node = minruby_parse(gets)

puts "  .intel_syntax noprefix"
puts "  .globl main"
puts "main:"
puts "  push rbp"
puts "  mov rbp, rsp"

gen(node)

puts "  pop rbp"
puts "  ret"
