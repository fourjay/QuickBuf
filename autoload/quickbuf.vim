if exists('did_quickbuf') || &compatible  || v:version < 703
    finish
endif
let g:did_quickbuf = 'did_quickbuf'
let s:save_cpo = &cpoptions
set compatible&vim

function! quickbuf#run()
    call quickbuf#init(1)
    call quickbuf#sbrun()
endfunction

let s:action2cmd = {
            \   'z': 'call <SID>switchbuf(#,"")',
            \  '!z': 'call <SID>switchbuf(#,"!")',
            \   'u': 'hid b #|let s:global.cursel = (s:global.cursel+1) % s:global.blen',
            \   's': 'sb #',
            \   'd': 'call <SID>qbufdcmd(#,"")',
            \  '!d': 'call <SID>qbufdcmd(#,"!")',
            \   'w': 'bw #', '!w': 'bw! #',
            \   'l': 'let s:global.unlisted = 1 - s:global.unlisted',
            \   'c': 'call <SID>closewindow(#,"")',
            \ }

        " \   'buflist ' : [],
let s:global = {
            \   'unlisted' : '',
            \   'blen'     : '',
            \   'cursel'   : '',
            \ }

function! quickbuf#get_global(...)
    if a:0 == 0
        return s:global
    else
        return s:global[a:1]
    endif
endfunction

function! s:rebuild() abort
    redir => l:ls_result | silent ls! | redir END
    let s:global.buflist = []
    let s:global.blen = 0

    for l:theline in split(l:ls_result,"\n")
        if s:global.unlisted && l:theline[3] ==# 'u' && (l:theline[6] !=# '-' || l:theline[5] !=# ' ')
                    \ || !s:global.unlisted && l:theline[3] !=# 'u'
            if s:global.unlisted
                let l:moreinfo = substitute(l:theline[5], '[ah]', ' [+]', '')
            else
                let l:moreinfo = substitute(l:theline[7], '+', ' [+]', '')
            endif
            let s:global.blen += 1
            let l:fname = matchstr(l:theline, '"\zs[^"]*')
            let l:bufnum = matchstr(l:theline, '^ *\zs\d*')

            if l:bufnum == bufnr('')
                let l:active = '* '
            elseif bufwinnr(str2nr(l:bufnum)) > 0
                let l:active = '= '
            else
                let l:active = '  '
            endif

            call add(s:global.buflist, s:global.blen . l:active
                        \ .fnamemodify(l:fname, ':t') . l:moreinfo
                        \ .' <' . l:bufnum . '> '
                        \ .fnamemodify( l:fname, ':h'))
        endif
    endfor

    let l:alignsize = max(map(copy(s:global.buflist),'stridx(v:val,">")'))
    call map(s:global.buflist, 'substitute(v:val, " <", repeat(" ",l:alignsize-stridx(v:val,">"))." <", "")')
    call map(s:global.buflist, 'strpart(v:val, 0, &columns-3)')
endfunc

function! quickbuf#sbrun() abort
    if !exists('s:global.cursel') || (s:global.cursel >= s:global.blen) || (s:global.cursel < 0)
        let s:global.cursel = s:global.blen-1
    endif

    if s:global.blen < 1
        echoh WarningMsg | echo 'No' s:global.unlisted ? 'unlisted' : 'listed' 'buffer!' | echoh None
        call quickbuf#init(0)
        return
    endif
    for l:idx in range(s:global.blen)
        if l:idx != s:global.cursel
            echo '  ' . s:global.buflist[l:idx]
        else
            echoh DiffText | echo '> ' . s:global.buflist[l:idx] | echoh None
        endif
    endfor

    if s:global.unlisted
        echoh WarningMsg
    endif
    " Fix input not receiving commands if paste is on
    let l:pasteon = 0
    if &paste
        let l:pasteon = 1
        set nopaste
    endif
    let l:pkey = input(s:global.unlisted ? 'UNLISTED ([+] loaded):' : 'LISTED ([+] modified):' , ' ')
    if l:pasteon
        set paste
    endif
    if s:global.unlisted
        echoh None
    endif
    if l:pkey =~# 'j$'
        let s:global.cursel = (s:global.cursel+1) % s:global.blen
    elseif l:pkey =~# 'k$'
        if s:global.cursel == 0
            let s:global.cursel = s:global.blen - 1
        else
            let s:global.cursel -= 1
        endif
    elseif s:update_buf(l:pkey)
        call quickbuf#init(0)
        return
    endif
    call quickbuf#setcmdh(s:global.blen+1)
endfunc

let s:orig_lazyredraw = &lazyredraw
function! quickbuf#init(onStart) " abort
    if a:onStart
        set nolazyredraw
        let s:global.unlisted = 1 - getbufvar('%', '&buflisted')
        let s:cursorbg = synIDattr(hlID('Cursor'),'bg')
        let s:cursorfg = synIDattr(hlID('Cursor'),'fg')
        let s:cmdh = &cmdheight
        hi Cursor guibg=NONE guifg=NONE

        let s:klist = ['j', 'k', 'u', 'd', 'w', 'l', 's', 'c']
        for l:key in s:klist
            execute 'cnoremap ' . l:key . ' ' . l:key . '<cr>:call quickbuf#sbrun()<cr>'
        endfor
        cmap <up> k
        cmap <down> j

        call s:rebuild()
        let s:global.cursel = match(s:global.buflist, '^\d*\*')
        call quickbuf#setcmdh(s:global.blen+1)
    else
        call quickbuf#setcmdh(1)
        for l:key in s:klist
            execute 'cunmap '.l:key
        endfor
        cunmap <up>
        cunmap <down>
        " execute 'hi Cursor guibg=' . s:cursorbg . " guifg=".((s:cursorfg == "") ? "NONE" : s:cursorfg)
        let &lazyredraw = s:orig_lazyredraw
    endif
endfunc

" return true to indicate termination
function! s:update_buf(cmd) abort
    if a:cmd !=# '' && a:cmd =~# '^ *\d*!\?\a\?$'
        let l:bufidx = str2nr(a:cmd) - 1
        if l:bufidx == -1
            let l:bufidx = s:global.cursel
        endif

        let l:action = matchstr(a:cmd, '!\?\a\?$')
        if l:action ==# '' || l:action ==# '!'
            let l:action .= 'z'
        endif

        if l:bufidx >= 0 && l:bufidx < s:global.blen && has_key(s:action2cmd, l:action)
            try
                execute substitute(s:action2cmd[l:action], '#', matchstr(s:global.buflist[l:bufidx], '<\zs\d\+\ze>'), 'g')
                if l:action[-1:] !=# 'z'
                    call s:rebuild()
                endif
            catch
                echoh ErrorMsg | echo "\rVIM" matchstr(v:exception, '^Vim(\a*):\zs.*') | echoh None
                if l:action[-1:] !=# 'z'
                    call inputsave() | call getchar() | call inputrestore()
                endif
            endtry
        endif
    endif
    return index(s:klist, a:cmd[-1:]) == -1
endfunc

function! quickbuf#setcmdh(height) abort
    if a:height > &lines - winnr('$') * (&winminheight+1) - 1
        call quickbuf#init(0)
        echo "\r"|echoerr 'QBuf E1: No room to display buffer list'
    else
        execute 'set cmdheight='.a:height
    endif
endfunc

function! s:switchbuf(bno, mod) abort
    if bufwinnr(a:bno) == -1
        execute 'b'.a:mod a:bno
    else
        execute bufwinnr(a:bno) . 'winc w'
    endif
endfunc

function! s:qbufdcmd(bno, mod) abort
    if s:global.unlisted
        call setbufvar(a:bno, '&buflisted', 1)
    else
        execute 'bd' . a:mod a:bno
    endif
endfunc

function! s:closewindow(bno, mod) abort
    if bufwinnr(a:bno) != -1
        execute bufwinnr(a:bno) . 'winc w|close' . a:mod
    endif
endfunc
" Cleanup at end
let &cpoptions = s:save_cpo
