

" Set directory where temporary files can be stored.
if !exists('g:winslow#TmpDir')
	if has('Unix')
		if exists('$TMPDIR') 
			let g:winslow#TmpDir = s:SetSlashes($TMPDIR) . 'vim/'
		else
			let g:winslow#TmpDir = '/var/tmp/vim/'
		endif
	elseif has('Windows') && exists('$TEMP') 
		let g:winslow#TmpDir = s:SetSlashes($TEMP) . 'vim/'
	else
		let g:winslow#TmpDir = './.vim/tmp/'
	end
end

" File to backup current configuration before custom settings are applied
if !exists('g:winslow#easyModeTeardownFile')
	let g:winslow#easyModeTeardownFile = g:winslow#TmpDir . 'easyModeTeardown.exrc'
endif



" Function to setup custom "easy mode" configurations, and also prep an
" exrc file to undo them
function! ActivateCustomEasyMode()

    " Make a backup of current settings and mappings (see :help mkexrc)
    exe 'mkexrc! ' . fnameescape(g:winslow#easyModeTeardownFile)

    " Use select mode instead of visual mode
    set selectmode=mouse,key,cmd

    " Use insert mode instead of normal mode
    set insertmode

endfunction


