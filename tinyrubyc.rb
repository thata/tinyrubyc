require 'minruby'

# 受け取った構文木からアセンブリコードを生成する
def gen(node)
  if node[0] == "lit"
    # 整数の場合
    # 例 : node = ["lit", 123]
    puts "  mov rax, #{node[1]}"
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
