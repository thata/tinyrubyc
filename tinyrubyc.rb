require 'minruby'

VAR_BYTE_WIDTH = 8 # 変数のバイト幅は8バイト (= 64ビット)

# 構文木内の var_assigns ノードを収集する
def collect_var_assign_nodes(node)
  case node[0]
  when "var_assign"
    # TODO: 代入式の右辺に変数が含まれる場合の対応は未実装
    [node]
  when "stmts"
    stmts = node[1..]
    var_assigns = []
    stmts.each do |stmt|
      var_assigns += collect_var_assign_nodes(stmt)
    end
    var_assigns
  else
    []
  end
end

# 構文木内の変数名一覧を取得する
def collect_var_names(node)
  var_assigns = collect_var_assign_nodes(node)
  var_assigns.map { |var_assign| var_assign[1] }.uniq.sort
end

# 指定した変数の格納場所を、ベースポインタ(rbp)からのオフセット値を返す
# 例：
#   一つ目の変数のメモリアドレス = ベースポインタ(RBP) - 8
#   二つ目の変数のメモリアドレス = ベースポインタ(RBP) - 16
#   三つ目の変数のアドレス = ベースポインタ(RBP) - 24
#   ...
def var_offset(var_name, env)
  # 変数名が見つからない場合はエラー
  raise "undefined local variable: #{var_name}" unless env.include?(var_name)

  (env.index(var_name) + 1) * VAR_BYTE_WIDTH
end

# 受け取った構文木からアセンブリコードを生成する
def gen(node, env)
  case node[0]
  when "lit"
    # 整数の場合
    # 例 : node = ["lit", 123]
    puts "  mov rax, #{node[1]}"
  when "+", "-", "*", "/"
    # 四則演算の場合
    # 例 : node = ["+", ["lit", 1], ["lit", 2]]

    # r12 と r13 の値をスタックへ退避
    puts "  push r12"
    puts "  push r13"

    # 左辺の計算結果を r12 へ格納
    gen(node[1], env)
    puts "  mov r12, rax"

    # 右辺の計算結果を r13 へ格納
    gen(node[2], env)
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
  when "==", "!=", ">", ">=", "<", "<="
    # 比較演算の場合
    # 例 : node = ["==", ["lit", 1], ["lit", 2]]

    # r12 と r13 の値をスタックへ退避
    puts "  push r12"
    puts "  push r13"

    # 左辺の計算結果を r12 へ格納
    gen(node[1], env)
    puts "  mov r12, rax"

    # 右辺の計算結果を r13 へ格納
    gen(node[2], env)
    puts "  mov r13, rax"

    case node[0]
    when "=="
      puts "  cmp r12, r13"
      puts "  sete al"
      puts "  movzx rax, al"
    when "!="
      puts "  cmp r12, r13"
      puts "  setne al"
      puts "  movzx rax, al"
    when ">"
      puts "  cmp r12, r13"
      puts "  setg al"
      puts "  movzx rax, al"
    when ">="
      puts "  cmp r12, r13"
      puts "  setge al"
      puts "  movzx rax, al"
    when "<"
      puts "  cmp r12, r13"
      puts "  setl al"
      puts "  movzx rax, al"
    when "<="
      puts "  cmp r12, r13"
      puts "  setle al"
      puts "  movzx rax, al"
    end

    # r12 と r13 の値をスタックから復元
    puts "  pop r13"
    puts "  pop r12"
  when "func_call"
    # 引数を評価して rdi レジスタにセット
    gen(node[2], env)
    puts "  mov rdi, rax"

    # 関数を呼び出す
    puts "  call #{node[1]}"
  when "stmts"
    # 文を要素として持つ配列を取得
    stmts = node[1..]
    stmts.each do |stmt|
      gen(stmt, env)
    end
  when "var_assign"
    var_name = node[1]

    # 変数名が見つからない場合はエラー
    raise "undefined local variable: #{var_name}" unless env.include?(var_name)

    # 代入式の右辺を評価
    gen(node[2], env)

    # スタック上のローカル変数領域へ評価結果を格納
    offset = var_offset(var_name, env)
    puts "  mov [rbp-#{offset}], rax"
  when "var_ref"
    var_name = node[1]

    # 変数名が見つからない場合はエラー
    raise "undefined local variable: #{var_name}" unless env.include?(var_name)

    # スタック上のローカル変数領域から値を取得
    offset = var_offset(var_name, env)
    puts "  mov rax, [rbp-#{offset}]"
  when "if"
    # if の場合
    # 例 :
    #   if (0 == 0); p(42); else; p(43); end
    #   => ["if",
    #        ["==", ["lit", 0], ["lit", 0]],
    #        ["func_call", "p", ["lit", 42]],
    #        ["func_call", "p", ["lit", 43]]]

    # 条件式を評価
    cond_exp = node[1]
    gen(cond_exp, env)

    # 真の場合は then_exp を評価
    puts "  cmp rax, 0"
    puts "  je .Lelse#{node.object_id}"
    then_exp = node[2]
    gen(then_exp, env)
    puts "  jmp .Lend#{node.object_id}"

    # 偽の場合は else_exp を評価
    else_exp = node[3]
    puts ".Lelse#{node.object_id}:"
    gen(else_exp, env) if else_exp
    puts ".Lend#{node.object_id}:"
  else
    raise "invalid AST error: #{node}"
  end
end

# 入力をパースする
node = minruby_parse(gets)

# 変数名一覧を取得
env = collect_var_names(node)

puts "  .intel_syntax noprefix"
puts "  .globl main"
puts "main:"
puts "  push rbp"
puts "  mov rbp, rsp"

# ローカル変数用の領域をスタック上に確保
puts "  sub rsp, #{env.size * VAR_BYTE_WIDTH}"

gen(node, env)

# スタック上に確保したローカル変数領域を解放
puts "  add rsp, #{env.size * VAR_BYTE_WIDTH}"

puts "  pop rbp"
puts "  ret"
