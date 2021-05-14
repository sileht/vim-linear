" linear.vim - fugitive.vim extension for GitHub
" Maintainer: Mehdi Abaakouk <sileht@sileht.net>

if exists("g:loaded_linear") || v:version < 700 || &cp
  finish
endif
let g:loaded_linear = 1

if !exists('g:dispatch_compilers')
  let g:dispatch_compilers = {}
endif
let g:dispatch_compilers['hub'] = 'git'

function! s:SetUpMessage(filename) abort
  if &omnifunc !~# '^\%(syntaxcomplete#Complete\)\=$' ||
        \ a:filename !~# '\.git[\/].*MSG$' ||
        \ !exists('*FugitiveFind')
    return
  endif
  let dir = exists('*FugitiveConfigGetRegexp') ? FugitiveGitDir() : FugitiveExtractGitDir(a:filename)
  if empty(dir)
    return
  endif
  let config_file = FugitiveFind('.git/config', dir)
  let config = filereadable(config_file) ? readfile(config_file) : []
  setlocal omnifunc=linear#Complete
endfunction

augroup linear
  autocmd!
  if exists('+omnifunc')
    autocmd FileType gitcommit call s:SetUpMessage(expand('<afile>:p'))
  endif
  autocmd BufEnter *
        \ if expand('%') ==# '' && &previewwindow && pumvisible() && getbufvar('#', '&omnifunc') ==# 'linear#omnifunc' |
        \    setlocal nolist linebreak filetype=markdown |
        \ endif
  autocmd BufNewFile,BufRead *.git/{PULLREQ_EDIT,ISSUE_EDIT,RELEASE_EDIT}MSG
        \ if &ft ==# '' || &ft ==# 'conf' |
        \   set ft=gitcommit |
        \ endif
augroup END
