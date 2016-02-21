let s:V = vital#of('vital')
call s:V.unload()
let s:DbC = s:V.import('Vim.DbC')
execute s:V.import('Vim.PowerAssert').define('Assert')

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

for i in range(1, 15)
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
