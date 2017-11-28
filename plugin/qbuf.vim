if v:version < 700
    finish
endif

if exists('g:qb_loaded') && g:qb_loaded
    finish
endif
let g:qb_loaded = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

nnoremap <Plug>quickbuf :call quickbuf#run()<cr>

if mapcheck('<F4>') ==# ''
    nmap <F4> <Plug>quickbuf
endif

let &complete = s:save_cpo
