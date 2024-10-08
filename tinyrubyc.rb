require 'minruby'

VAR_BYTE_WIDTH = 8 # 変数のバイト幅は8バイト (= 64ビット)

 # 関数へ引数を渡すのに使用するレジスタ
 # see: https://scrapbox.io/htkymtks/x86-64%E3%81%AE%E3%83%AC%E3%82%B8%E3%82%B9%E3%82%BF
 ARG_REGISTERS = ["rdi", "rsi", "rdx", "rcx", "r8", "r9"]

# 構文木内の func_def ノードを収集する
def collect_func_def_nodes(node)
  case node[0]
  when "func_def"
    [node]
  when "stmts"
    stmts = node[1..]
    func_defs = []
    stmts.each do |stmt|
      func_defs += collect_func_def_nodes(stmt)
    end
    func_defs
  else
    []
  end
end

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
  when "if"
    var_assigns = []
    # 条件式内の var_assigns ノードを収集
    var_assigns += collect_var_assign_nodes(node[1])
    # then ブロック内の var_assigns ノードを収集
    var_assigns += collect_var_assign_nodes(node[2])
    # else ブロック内の var_assigns ノードを収集
    if node[3]
      var_assigns += collect_var_assign_nodes(node[3])
    end
    var_assigns
  when "while"
    var_assigns = []
    # 条件式内の var_assigns ノードを収集
    var_assigns += collect_var_assign_nodes(node[1])
    # body ブロック内の var_assigns ノードを収集
    var_assigns += collect_var_assign_nodes(node[2])
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
    args = node[2..]

    # 引数が6個以上の場合はエラー
    raise "too many arguments (given #{args.size}, expected 6)" if args.size > 6

    # 関数の引数を評価してスタックへ退避する
    args.each do |arg|
      gen(arg, env)
      puts "  push rax"
    end

    # スタックへ退避した引数を、引数渡し用のレジスタへセット
    args.each_with_index.reverse_each do |_, i|
      puts "  pop rax"
      puts "  mov #{ARG_REGISTERS[i]}, rax"
    end

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
  when "while"
    # while の場合
    # 例 : while (0==0); p(10) end
    #   => ["while", ["==", ["lit", 0], ["lit", 0]], ["func_call", "p", ["lit", 10]]]

    # 開始ラベル
    puts ".Lwhile_begin#{node.object_id}:"

    # 条件式を評価
    cond_exp = node[1]
    gen(cond_exp, env)

    # 真の場合は body_exp を評価
    puts "  cmp rax, 0"
    puts "  je .Lwhile_end#{node.object_id}"
    body_exp = node[2]
    gen(body_exp, env)

    # 条件式を評価するため、ループの先頭にジャンプ
    puts "  jmp .Lwhile_begin#{node.object_id}"

    # 終了ラベル
    puts ".Lwhile_end#{node.object_id}:"
  when "func_def"
    # ここでは何も行わない
  else
    raise "invalid AST error: #{node}"
  end
end

# 入力をパースする
node = minruby_parse(ARGF.read)

# 関数一覧を取得
func_defs = collect_func_def_nodes(node)

puts "  .intel_syntax noprefix"

# ユーザー定義関数
func_defs.each do |func_def|
  func_name = func_def[1]
  func_args = func_def[2]
  func_body = func_def[3]

  puts "  .globl #{func_name}"
  puts "#{func_name}:"
  puts "  push rbp"
  puts "  mov rbp, rsp"

  # ローカル変数一覧（含む引き数）
  env = func_args + collect_var_names(func_body)

  # ローカル変数用の領域をスタック上に確保
  puts "  sub rsp, #{env.size * VAR_BYTE_WIDTH}"

  # 引数をローカル変数領域へ格納
  func_args.each_with_index do |arg, i|
    offset = var_offset(arg, env)
    puts "  mov [rbp-#{offset}], #{ARG_REGISTERS[i]}"
  end

  gen(func_body, env)

  # スタック上に確保したローカル変数領域を解放
  puts "  add rsp, #{env.size * VAR_BYTE_WIDTH}"

  puts "  pop rbp"
  puts "  ret"
end

# メイン関数
puts "  .globl main"
puts "main:"
puts "  push rbp"
puts "  mov rbp, rsp"

# ローカル変数一覧
env = collect_var_names(node)

# ローカル変数用の領域をスタック上に確保
puts "  sub rsp, #{env.size * VAR_BYTE_WIDTH}"

gen(node, env)

# スタック上に確保したローカル変数領域を解放
puts "  add rsp, #{env.size * VAR_BYTE_WIDTH}"

puts "  pop rbp"
puts "  ret"
