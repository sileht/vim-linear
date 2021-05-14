" Location: autoload/linear.vim
" Author: Mehdi Abaakouk <sileht@sileht.net>

if exists('g:autoloaded_linear')
  finish
endif
let g:autoloaded_linear = 1

" Section: Utility

function! s:throw(string) abort
  let v:errmsg = 'linear: '.a:string
  throw v:errmsg
endfunction

function! s:shellesc(arg) abort
  if a:arg =~# '^[A-Za-z0-9_/.-]\+$'
    return a:arg
  elseif &shell =~# 'cmd' && a:arg !~# '"'
    return '"'.a:arg.'"'
  else
    return shellescape(a:arg)
  endif
endfunction

" Section: HTTP

function! linear#JsonDecode(string) abort
  if exists('*json_decode')
    return json_decode(a:string)
  endif
  let [null, false, true] = ['', 0, 1]
  let stripped = substitute(a:string,'\C"\(\\.\|[^"\\]\)*"','','g')
  if stripped !~# "[^,:{}\\[\\]0-9.\\-+Eaeflnr-u \n\r\t]"
    try
      return eval(substitute(a:string,"[\r\n]"," ",'g'))
    catch
    endtry
  endif
  call s:throw("invalid JSON: ".a:string)
endfunction

function! linear#JsonEncode(object) abort
  if exists('*json_encode')
    return json_encode(a:object)
  endif
  if type(a:object) == type('')
    return '"' . substitute(a:object, "[\001-\031\"\\\\]", '\=printf("\\u%04x", char2nr(submatch(0)))', 'g') . '"'
  elseif type(a:object) == type([])
    return '['.join(map(copy(a:object), 'linear#JsonEncode(v:val)'),', ').']'
  elseif type(a:object) == type({})
    let pairs = []
    for key in keys(a:object)
      call add(pairs, linear#JsonEncode(key) . ': ' . linear#JsonEncode(a:object[key]))
    endfor
    return '{' . join(pairs, ', ') . '}'
  else
    return string(a:object)
  endif
endfunction

function! s:curl_arguments(path, ...) abort
  let options = a:0 ? a:1 : {}
  let args = ['-q', '--silent']
  call extend(args, ['-H', 'Accept: application/json'])
  call extend(args, ['-H', 'Content-Type: application/json'])
  call extend(args, ['-A', 'linear.vim'])
  if get(options, 'auth', '') =~# ':'
    call extend(args, ['-u', options.auth])
  elseif has_key(options, 'auth')
    call extend(args, ['-H', 'Authorization: ' . options.auth])
  elseif exists('g:LINEAR_TOKEN')
    call extend(args, ['-H', 'Authorization: ' . g:LINEAR_TOKEN])
  elseif has('win32') && filereadable(expand('~/.netrc'))
    call extend(args, ['--netrc-file', expand('~/.netrc')])
  else
    call extend(args, ['--netrc'])
  endif
  if has_key(options, 'method')
    call extend(args, ['-X', toupper(options.method)])
  endif
  for header in get(options, 'headers', [])
    call extend(args, ['-H', header])
  endfor
  if type(get(options, 'data', '')) != type('')
    call extend(args, ['-d', linear#JsonEncode(options.data)])
  elseif has_key(options, 'data')
    call extend(args, ['-d', options.data])
  endif
  call add(args, a:path)
  return args
endfunction

function! linear#Request(...) abort
  if !executable('curl')
    call s:throw('cURL is required')
  endif
  let path = 'https://api.linear.app/graphql'
  let options = a:0 ? a:1 : {}
  let args = s:curl_arguments(path, options)
  let raw = system('curl '.join(map(copy(args), 's:shellesc(v:val)'), ' '))
  if raw ==# ''
    return raw
  else
    return linear#JsonDecode(raw)
  endif
endfunction

function! linear#request(...) abort
  return call('linear#Request', a:000)
endfunction

function! s:url_encode(str) abort
  return substitute(a:str, '[?@=&<>%#/:+[:space:]]', '\=submatch(0)==" "?"+":printf("%%%02X", char2nr(submatch(0)))', 'g')
endfunction

function! linear#IssueSearch() abort
  let issues = []
  for id in  g:LINEAR_STATE_IDS
      let data = linear#Request({"data": '{ "query": "{ workflowState(id: \"'.id.'\" ) { issues(orderBy: updatedAt) { nodes { identifier title description state{name}} } } }"}'})
      call extend(issues, data.data.workflowState.issues.nodes)
  endfor
  return issues
endfunction

function! linear#issue_search(...) abort
  return call('linear#IssueSearch', a:000)
endfunction

function! linear#startsWith(longer, shorter) abort
  return a:longer[0:len(a:shorter)-1] ==# a:shorter
endfunction

" Section: Issues

let s:reference = '\<\%(\c\%(clos\|resolv\|referenc\)e[sd]\=\|\cfix\%(e[sd]\)\=\)\>'
function! linear#Complete(findstart, base) abort
  if a:findstart
    let existing = matchstr(getline('.')[0:col('.')-1],s:reference.'\s\+\zs[^#/,.;]*$\|[#@[:alnum:]-]*$')
    return col('.')-1-strlen(existing)
  endif
  try
    let issues = linear#IssueSearch()
    if (a:base != "")
        call filter(issues, ':val.identifier[0:len("'.a:base.'")-1] ==# "'.a:base.'')
    endif
    let res = map(issues, '{"word": v:val.identifier, "abbr": v:val.identifier, "menu": v:val.title." [".v:val.state.name."]", "info": substitute(empty(v:val.description) ? "\n" : v:val.description,"\\r","","ig")}')
    return res
  catch /^\%(fugitive\|linear\):/
    echoerr v:errmsg
  endtry
endfunction

function! linear#omnifunc(findstart, base) abort
  return linear#Complete(a:findstart, a:base)
endfunction

" Section: End
