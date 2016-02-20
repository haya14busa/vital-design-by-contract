" Design By Contract
let g:vital_vim_dbc = {'store': {}}

"" Type definition
" @typedef {in} a:var argument of function
" @typedef {out} Any returned value of function

" s:hookdef() returns hook definition string to execute before or/and after
" given func.
" @param {Funcref|string} func
" @param {{pre: (in) => Unit, post: (in, out) => Unit}} config
" @return {string}
" pre: execute before func
" post: execute after func
" Example:
" >>> function! s:test() abort
" >>>   echo 'test'
" >>> endfunction
"
" >>> function! s:__pre_test(in) abort
" >>>   echo 'pre_test'
" >>> endfunction
"
" >>> function! s:__post_test(in, out) abort
" >>>   echo 'post_test'
" >>> endfunction
"
" >>> execute s:hookdef(function('s:test'), {
" >>> \   'pre': function('s:__pre_test'),
" >>> \   'post': function('s:__post_test')
" >>> \ })
" >>> call s:test()
" pre_test
" test
" post_test
function! s:hookdef(func, config) abort
  let l:Pre = get(a:config, 'pre', function('s:_nothing'))
  let l:Post = get(a:config, 'post', function('s:_nothing'))
  let funcname = type(a:func) is# type('') ? a:func : s:funcname(a:func)
  let g:vital_vim_dbc.store[funcname] = {
  \   'pre': type(l:Pre) is# type('') ? function(l:Pre) : l:Pre,
  \   'post': type(l:Post) is# type('') ? function(l:Post) : l:Post
  \ }
  let copyfuncname = funcname . '___dbc_copied_func___'
  let copyfuncdef = s:copyfuncdef(funcname, copyfuncname)
  " extract args and fix a: argument for pre and post func
  let [args, _] = s:extract_args(funcname)
  let defcopyfunc = [
  \   printf('execute "%s"', escape(copyfuncdef, '"')),
  \   printf('let g:vital_vim_dbc.store[''%s''].func = function(''%s'')', funcname, copyfuncname)
  \ ]
  let redefine = [
  \          'function! ' . funcname . '(...) abort',
  \          '  let s = exists(''self'') ? self : {}',
  \   printf('  let a = g:Vital_dbc_fixa(a:, %s)', string(args)),
  \   printf('  call call(g:vital_vim_dbc.store[''%s''].pre, [a], s)', funcname),
  \   printf('  let r = call(g:vital_vim_dbc.store[''%s''].func, a:000, s)', funcname),
  \   printf('  call call(g:vital_vim_dbc.store[''%s''].post, [a, r], s)', funcname),
  \          '  return r',
  \          'endfunction'
  \ ]
  return join(defcopyfunc + redefine, "\n")
endfunction

" s:funcname() converts funcref to its funcname
" @param {Funcref} funcref
" @return {string}
function! s:funcname(funcref) abort
  return substitute(string(a:funcref), '\m^function(''\(.*\)'')$', '\1', '')
endfunction

" Vital_dbc_fixa() fixes a: of func(...) to a: of func(a, b, ...) from args.
"   1. Add each arg as key to given a: so that users can use a:var
"   2. Fix a:0 and shift a:1, a:2, ..., a:n
"   3. Fix a:000 number
" @param {a:} a
" @param {list<string>} args
" @return {a:}
function! Vital_dbc_fixa(a, args) abort
  let fixa = copy(a:a)
  let arglen = len(a:args)
  " 1. add arg name reference
  for i in range(arglen)
    let argname = a:args[i]
    let fixa[argname] = fixa['000'][i]
  endfor
  " 2. fix a:0
  let fixa[0] = fixa[0] - arglen
  " 2. fix a:1, a:2, ... a:n
  for i in range(1, len(a:a['000']) - len(a:args))
    let fixa[i] = a:a['000'][i + arglen - 1]
    call remove(fixa, i + arglen)
  endfor
  " 3. fix a:000
  let fixa['000'] = fixa['000'][arglen :]
  return fixa
endfunction

" s:extract_args() extracts arguments of function and returns it with bool
" which indicates whether the func accepts extra arguments or not.
" @param {string} funcname
" @return {Tuple<list<string>, bool>}
function! s:extract_args(funcname) abort
  let funcdef = s:_capture_lines(":function " . a:funcname)[0]
  let argstr = matchstr(funcdef, '\m(\zs.*\ze)')
  let args = split(argstr, ', ')
  if empty(args)
    return [[], 0]
  endif
  let has_extra = args[-1] is# '...'
  if has_extra
    call remove(args, -1)
  endif
  return [args, has_extra]
endfunction

" s:copyfuncdef() returns executable string which copy given function to
" another new function.
" @param {string} funcname
" @param {string} tofuncname
function! s:copyfuncdef(funcname, tofuncname) abort
  let funcdef = s:capturefunc(a:funcname)
  let defline = s:_rebuild_defline(funcdef[0], a:tofuncname)
  let restlines = funcdef[1:]
  retur join([defline] + restlines, "\n")
endfunction

function! s:_rebuild_defline(defline, tofuncname) abort
  let l = a:defline
  let l = substitute(l, '^\s*\zsfunction', 'function!', '')
  let l = substitute(l, '^\s*function!\s\zs[^(]*\ze(', a:tofuncname, '')
  return l
endfunction

function! s:capturefunc(funcname) abort
  let f = 'substitute(v:val, ''^\d\+'', "", "")'
  let funcdef = map(s:_capture_lines(":function " . a:funcname), f)
  return funcdef
endfunction

" Capture command
function! s:_capture(command) abort
  try
    let save_verbose = &verbose
    let &verbose = 0
    redir => out
    silent execute a:command
  finally
    redir END
    let &verbose = save_verbose
  endtry
  return out
endfunction

" Capture command and return lines
function! s:_capture_lines(command) abort
  return split(s:_capture(a:command), "\n")
endfunction

function! s:_nothing(...) abort
endfunction
