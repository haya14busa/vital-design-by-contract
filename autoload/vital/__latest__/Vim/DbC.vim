function! s:_vital_loaded(V) abort
  let s:V = a:V
  let s:ScriptLocal = s:V.import('Vim.ScriptLocal')
endfunction

function! s:_vital_depends() abort
  return ['Vim.ScriptLocal']
endfunction

function! s:_SID() abort
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze__SID$')
endfunction
let s:_s = '<SNR>' . s:_SID() . '_'
delfunction s:_SID
function! s:_sfunc(funcname) abort
  return substitute(a:funcname, '^s:', s:_s, '')
endfunction

" Design By Contract
let s:funcstore = {}

" @param {string} keyfuncname
" @param {'func'|'pre'|'post'} key
" @param {Funcref} func
function! s:_store(keyfuncname, key, func) abort
  if !has_key(s:funcstore, a:keyfuncname)
    let s:funcstore[a:keyfuncname] = {}
  endif
  let s:funcstore[a:keyfuncname][a:key] = a:func
endfunction

" @param {string} keyfuncname
" @param {'func'|'pre'|'post'} key
" @param {list<any>} args
" @param {dict} dict
function! s:_run(keyfuncname, key, args, dict) abort
  return call(s:funcstore[a:keyfuncname][a:key], a:args, a:dict)
endfunction

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
  let l:Pre = get(a:config, 'pre', s:_NOTHING)
  let l:Post = get(a:config, 'post', s:_NOTHING)
  let funcname = type(a:func) is# type('') ? a:func : s:funcname(a:func)
  call s:_store(funcname, 'pre', type(l:Pre) is# type('') ? function(l:Pre) : l:Pre)
  call s:_store(funcname, 'post', type(l:Post) is# type('') ? function(l:Post) : l:Post)

  let copyfuncname = funcname . '___dbc_copied_func___'
  let copyfuncdef = s:copyfuncdef(funcname, copyfuncname)

  " extract args and fix a: argument for pre and post func
  let [args, _] = s:extract_args(funcname)
  let defcopyfunc = [
  \   printf('execute "%s"', escape(copyfuncdef, '"')),
  \   printf('call %s(''%s'', ''func'', function(''%s''))', s:_sfunc('s:_store'), funcname, copyfuncname)
  \ ]

  let defline = substitute(s:_rebuild_defline(s:capturefunc(funcname)[0], funcname),
  \                        '\m(\zs.*\ze)', '...', '')

  let redefine = join([
  \          defline,
  \          '  let s = exists(''self'') ? self : {}',
  \   printf('  let a = %s(a:, %s)', s:_sfunc('s:_fixa'), string(args)),
  \   printf('  call %s(''%s'', ''pre'', [a], s)', s:_sfunc('s:_run'), funcname),
  \   printf('  let r = %s(''%s'', ''func'', a:000, s)', s:_sfunc('s:_run'), funcname),
  \   printf('  call %s(''%s'', ''post'', [a, r], s)', s:_sfunc('s:_run'), funcname),
  \          '  return r',
  \          'endfunction',
  \ ], "\n")
  " return join(defcopyfunc + redefine, "\n")
  return join(defcopyfunc + [printf('execute "%s"', escape(redefine, '"'))], "\n")
endfunction

" s:funcname() converts funcref to its funcname
" @param {Funcref} funcref
" @return {string}
function! s:funcname(funcref) abort
  return substitute(string(a:funcref), '\m^function(''\(.*\)'')$', '\1', '')
endfunction

" s:_fixa() fixes a: of func(...) to a: of func(a, b, ...) from args.
"   1. Add each arg as key to given a: so that users can use a:var
"   2. Fix a:0 and shift a:1, a:2, ..., a:n
"   3. Fix a:000 number
" @param {a:} a
" @param {list<string>} args
" @return {a:}
function! s:_fixa(a, args) abort
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
  for i in range(1, max([0, len(a:a['000']) - arglen]))
    let fixa[i] = a:a['000'][i + arglen - 1]
    call remove(fixa, i + arglen)
  endfor
  " 3. fix a:000
  let fixa['000'] = fixa['000'][arglen :]
  if len(fixa['000']) is# 0 && has_key(fixa, 1)
    call remove(fixa, 1)
  endif
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

let s:_NOTHING = function('s:_nothing')

" s:dbc() enables Design by Contract for specific script local functions.
"  1. s:__pre__{func} will be called before {func}
"  2. s:__post__{func} will be calles after {func}
" @return {executable_string}
function! s:dbc() abort
  return printf('execute %s(expand(''<sfile>''))', s:_sfunc('s:_dbc'))
endfunction

" @param {string} sfile
" @return {executable_string}
function! s:_dbc(sfile) abort
  if a:sfile =~# '/'
    let sfuncs = s:ScriptLocal.sfuncs(a:sfile)
  else
    let sfuncs = s:ScriptLocal.sid2sfuncs(matchstr(a:sfile, '<SNR>\zs\d\+\ze\w\+$'))
  endif
  let dbc_sfuncs = s:aggregate_dbc_sfuncs(sfuncs)
  let defs = []
  for dbc_sfunc in dbc_sfuncs
    let config = {'pre': dbc_sfunc.pre, 'post': dbc_sfunc.post}
    let defs += [s:hookdef(dbc_sfunc.func, config)]
  endfor
  return join(defs, "\n")
endfunction

" s:aggregate_dbc_sfuncs() aggregates script local functions to be hooked
" @param {{<funcname>: Funcref}}
" @return {list<{func: Funcref, pre: Funcref, post: Funcref}>}
function! s:aggregate_dbc_sfuncs(sfuncs) abort
  let PRE_PREFIX = '__pre_'
  let POST_PREFIX = '__post_'
  " @type {{<funcname>: {func: Funcref, pre: Funcref, post: Funcref}}}
  let dbc_funcs = {}
  let pattern = printf('\m\%%(%s\|%s\)\zs\w\+$', PRE_PREFIX, POST_PREFIX)
  for sfuncname in filter(keys(a:sfuncs), 'v:val =~# pattern')
    let mainfuncname = matchstr(sfuncname, pattern)
    if has_key(dbc_funcs, mainfuncname) || !has_key(a:sfuncs, mainfuncname)
      continue
    endif
    let dbc_funcs[mainfuncname] = {'func': a:sfuncs[mainfuncname]}
    let prefuncname = PRE_PREFIX . mainfuncname
    let postfuncname = POST_PREFIX . mainfuncname
    let dbc_funcs[mainfuncname].pre = get(a:sfuncs, prefuncname, s:_NOTHING)
    let dbc_funcs[mainfuncname].post = get(a:sfuncs, postfuncname, s:_NOTHING)
  endfor
  return values(dbc_funcs)
endfunction
