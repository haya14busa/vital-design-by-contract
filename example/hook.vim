let s:V = vital#of('vital')
let s:DbC = s:V.import('Vim.DbC')

function! s:test() abort
  echo 'test'
endfunction

function! s:__pre_test(in) abort
  echo 'pre_test'
endfunction

function! s:__post_test(in, out) abort
  echo 'post_test'
endfunction

execute s:DbC.hookdef(function('s:test'), {
\   'pre': function('s:__pre_test'),
\   'post': function('s:__post_test')
\ })

call s:test()
" =>
" pre_test
" test
" post_test
