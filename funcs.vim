
" Toggle quickfix list {{{

function! GetBufferList()
    redir =>buflist
    silent! ls!
    redir END
    return buflist
endfunction

" nnoremap <silent> <leader>el :call ToggleList("Location List", 'l')<CR>
nnoremap <silent> <leader>e :call ToggleList("Quickfix List", 'c')<CR>
function! ToggleList(bufname, pfx)
    let buflist = GetBufferList()
    for bufnum in map(filter(split(buflist, '\n'), 'v:val =~ "'.a:bufname.'"'), 'str2nr(matchstr(v:val, "\\d\\+"))')
        if bufwinnr(bufnum) != -1
            exec(a:pfx.'close')
            return
        endif
    endfor
    if a:pfx == 'l' && len(getloclist(0)) == 0
        echohl ErrorMsg
        echo "Location List is Empty."
        return
    endif
    let winnr = winnr()
    exec(a:pfx.'open')
    " if winnr() != winnr
    "     wincmd p
    " endif
endfunction


" [w ]w {{{1
" Move between tabs with [w ]w
" copied basic [] implementation from vim-unimpaired
function! s:MapNextFamily(map,cmd)
  let map = '<Plug>unimpairedCustom'.toupper(a:map)
  let cmd = '".(v:count ? v:count : "")."'.a:cmd
  let end = '"<CR>'.(a:cmd == 'l' || a:cmd == 'c' ? 'zv' : '')
  execute 'nnoremap <silent> '.map.'Previous :<C-U>exe "'.cmd.'previous'.end
  execute 'nnoremap <silent> '.map.'Next     :<C-U>exe "'.cmd.'next'.end
  execute 'nnoremap <silent> '.map.'First    :<C-U>exe "'.cmd.'first'.end
  execute 'nnoremap <silent> '.map.'Last     :<C-U>exe "'.cmd.'last'.end
  execute 'nmap <silent> ['.        a:map .' '.map.'Previous'
  execute 'nmap <silent> ]'.        a:map .' '.map.'Next'
  execute 'nmap <silent> ['.toupper(a:map).' '.map.'First'
  execute 'nmap <silent> ]'.toupper(a:map).' '.map.'Last'
  if exists(':'.a:cmd.'nfile')
    execute 'nnoremap <silent> '.map.'PFile :<C-U>exe "'.cmd.'pfile'.end
    execute 'nnoremap <silent> '.map.'NFile :<C-U>exe "'.cmd.'nfile'.end
    execute 'nmap <silent> [<C-'.a:map.'> '.map.'PFile'
    execute 'nmap <silent> ]<C-'.a:map.'> '.map.'NFile'
  endif
endfunction

call s:MapNextFamily('w','tab')

" diff {{{1

" toggle diff mode in open split
nnoremap <leader>d :ToggleDiff<CR>
command! ToggleDiff call ToggleDiff()
fu! ToggleDiff()
  if &diff == "nodiff"
    :windo difft
  else
    :diffo!
  endif
endfu

noremap ,s :call ToggleWhiteSpace()<CR>
function! ToggleWhiteSpace()
  if &diffopt =~ 'iwhite'
    set diffopt-=iwhite
  else
    set diffopt+=iwhite
  endif
endfunction

noremap ,a :call CycleDiffAlgorithms()<CR>
function! CycleDiffAlgorithms()
    let algorithms = ["myers", "minimal", "patience", "histogram"] " from :h diffopt

    let diffOptMatch = matchlist(&diffopt, 'algorithm:\([a-z]*\)')
    if len(diffOptMatch) > 0
      let currentOptValue = diffOptMatch[0]
      let currentAlgorithmName = diffOptMatch[1]
      let nextAlgIndex = index(algorithms , currentAlgorithmName) + 1
      if nextAlgIndex >= len(algorithms)
        let nextAlgIndex = 0 " loop list
      endif
      let &diffopt = substitute(&diffopt, currentOptValue, "algorithm:" . algorithms[nextAlgIndex], "")
    else
      " same as: set diffopt+=algorithm:patience
      let &diffopt = &diffopt . ",algorithm:" . algorithms[1]
    endif
endfunction

" Custom Par {{{1

function! CustomPar(start, end)
  let lines = getline(a:start, a:end) 
  let lines = AddNewlineAfterSlash(lines)

  let formattedLines = systemlist("par", lines)
  let formattedLines = RemoveNewlineAfterSlash(formattedLines)
  call add(formattedLines, "")		" Last newline was removed before

  execute 'silent ' . a:start . "," . a:end . "delete" 
  call append(a:start -1, formattedLines)
endfunction

fu! AddNewlineAfterSlash(lines)
  let specialLines = GetLinesEndingInSlash(a:lines)
  for cIndex in reverse(specialLines)
    call insert(a:lines, "", cIndex+1)
  endfor
  return a:lines
endfu

fu! RemoveNewlineAfterSlash(lines)
  let specialLines = GetLinesEndingInSlash(a:lines)
  for cIndex in reverse(specialLines)
    call remove(a:lines, cIndex+1)
  endfor
  return a:lines
endfu

fu! GetLinesEndingInSlash(lines)
  let specialLines = []
	let index = 0
	while index < len(a:lines)
	   let item = a:lines[index]
     if item =~ "\\\\$"
       call add(specialLines, index)
     endif
	   let index = index + 1
	endwhile
  return specialLines
endfu

" OpenOther {{{1
nnoremap ,t :call OpenOther()<CR>

fu! OpenOther()
  if &filetype == "java"
    call OpenOtherOnSuffix("/main/", "/test/", "Test")
  elseif &filetype == "sh"
    call OpenOtherOnPrefix("main", "test", "test_")
  endif
endfu

fu! OpenOtherOnPrefix(mainDirId, testDirId, testPrefix)
  " Files & paths
  let srcDir = GetRelativeFilePath()
  let srcFileName = expand('%:t')

  " Change path
  let targetPathItems = split(srcDir, '/')
  let mainIdIndex = index(targetPathItems, a:mainDirId)
  let testIdIndex = index(targetPathItems, a:testDirId)

  if (mainIdIndex > -1)
    let targetPathItems[mainIdIndex] = a:testDirId
  elseif (testIdIndex > -1)
    let targetPathItems[testIdIndex] = a:mainDirId
  endif

  " Change fileName
  if (srcFileName =~ "^" . a:testPrefix)
    call add(targetPathItems, substitute(srcFileName, a:testPrefix, "", ""))
  else
    call add(targetPathItems, a:testPrefix . srcFileName)
  endif

  execute 'edit ' . join(targetPathItems, "/")
endfu

fu! OpenOtherOnSuffix(mainDirId, testDirId, testSuffix)
  " Files & paths
  let srcDir = GetRelativeFilePath()
  let srcFile = expand('%:t')
  let extension = "." . expand('%:e')

  " Change path
  let targetPath = ""
  if (stridx(srcDir, a:mainDirId) > -1)
    let targetPath = substitute(srcDir, a:mainDirId, a:testDirId, "")
  elseif (stridx( srcDir, a:testDirId) > -1)
    let targetPath = substitute(srcDir, a:testDirId, a:mainDirId, "")
  endif

  " Change fileName
  let targetFile = ""
  if (stridx(srcFile, a:testSuffix . extension) > -1)
    let targetFile = substitute(srcFile, a:testSuffix . extension, extension, "")
  else
    let targetFile = substitute(srcFile, extension, a:testSuffix . extension, "")
  endif

  execute 'edit ' . targetPath . '/' . targetFile

endfu


fu! GetRelativeFilePath()
    let fullPath = expand('%:p:h')
    return substitute(fullPath, getcwd() . "/" , "", "")
endfu

" }}}

" autocmd FileType markdown set formatexpr=CustomPar(v:lnum,v:lnum+v:count-1)


"----------------------------------------------------------------
" vim:fdm=marker
