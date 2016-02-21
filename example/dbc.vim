let s:V = vital#of('vital')
let s:DbC = s:V.import('Vim.DbC')
execute s:V.import('Vim.PowerAssert').define('Assert')

function! s:flatten(list, ...) abort
  let limit = a:0 > 0 ? a:1 : -1
  let memo = []
  if limit == 0
    return a:list
  endif
  let limit -= 1
  for Value in a:list
    let memo +=
    \  type(Value) == type([]) ?
    \    s:flatten(Value, limit) :
    \    [Value]
    unlet! Value
  endfor
  return memo
endfunction

" s:__pre_{func}() will be called before {func} with a:var args as a:in
function! s:__pre_flatten(in) abort
  " input should be list
  Assert type(a:in.list) is# type([])
  " limit should be number
  Assert type(get(a:in, 1, 0)) is# type(0)
  " You can use a:in.var to access a:var
  echo '__pre_flatten : in : ' . string(a:in.list)
endfunction

" s:__post_{func}() will be called after {func} with a:var args as a:in and
" returned value as a:out
function! s:__post_flatten(in, out) abort
  " Each value of returned list should not be list
  for l:X in a:out
    Assert type(l:X) isnot# type([])
  endfor
  echo '__post_flatten: out: ' . string(a:out)
endfunction

function! s:fizzbuzz(n) abort
  return a:n % 15 ? a:n % 5 ? a:n % 3 ? a:n : 'Fizz' : 'Buzz' : 'FizzBuzz'
endfunction

function! s:__pre_fizzbuzz(in) abort
  " You can access a:in.var like a:var for input
  echo '__pre_fizzbuzz : in:' . a:in.n
  Assert type(a:in.n) is# type(0)
endfunction

function! s:__post_fizzbuzz(in, out) abort
  echo '__post_fizzbuzz: in:' . a:in.n . ' out: ' . a:out
  Assert type(a:out) is# type(0) || type(a:out) is# type('')
endfunction


execute s:DbC.dbc()

echo s:flatten([[1], [2, [3], [[4]]]])

for i in range(1, 10)
  echo s:fizzbuzz(i)
endfor
" =>
" __pre_fizzbuzz : in:1
" __post_fizzbuzz: in:1 out: 1
" 1
" __pre_fizzbuzz : in:2
" __post_fizzbuzz: in:2 out: 2
" 2
" __pre_fizzbuzz : in:3
" __post_fizzbuzz: in:3 out: Fizz
" Fizz
" __pre_fizzbuzz : in:4
" __post_fizzbuzz: in:4 out: 4
" 4
" __pre_fizzbuzz : in:5
" __post_fizzbuzz: in:5 out: Buzz
" Buzz
" __pre_fizzbuzz : in:6
" __post_fizzbuzz: in:6 out: Fizz
" Fizz
" __pre_fizzbuzz : in:7
" __post_fizzbuzz: in:7 out: 7
" 7
" __pre_fizzbuzz : in:8
" __post_fizzbuzz: in:8 out: 8
" 8
" __pre_fizzbuzz : in:9
" __post_fizzbuzz: in:9 out: Fizz
" Fizz
" __pre_fizzbuzz : in:10
" __post_fizzbuzz: in:10 out: Buzz
" Buzz
" __pre_fizzbuzz : in:11
" __post_fizzbuzz: in:11 out: 11
" 11
" __pre_fizzbuzz : in:12
" __post_fizzbuzz: in:12 out: Fizz
" Fizz
" __pre_fizzbuzz : in:13
" __post_fizzbuzz: in:13 out: 13
" 13
" __pre_fizzbuzz : in:14
" __post_fizzbuzz: in:14 out: 14
" 14
" __pre_fizzbuzz : in:15
" __post_fizzbuzz: in:15 out: FizzBuzz
" FizzBuzz
