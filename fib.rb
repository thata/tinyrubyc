# fib.rb: Calculate Fibonacci number
#
# usage:
#   $ ruby tinyrubyc.rb fib.rb > tmp.s
#   $ gcc -z noexecstack tmp.s libtinyruby.c
#   $ ./a.out
#   => 55
def fib(n)
  if n < 2
    n
  else
    fib(n-1) + fib(n-2)
  end
end

p fib(10)
