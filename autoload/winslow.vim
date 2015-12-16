" File:			winslow.vim
" Description:	Enhanced easy mode for Vim
" Author:		Brian Dellatera <github.com/bdellaterra>
" Version:		0.1.1
" License:      Copyright 2015 Brian Dellaterra. This file is part of Winslow.
" 				Distributed under the terms of the GNU Lesser General Public License.
"				See the file LICENSE or <http://www.gnu.org/licenses/>.


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

    " FILE MAPPINGS

    " <C-n>: Create new file
    inoremap  <silent> <C-n> <C-o>:confirm enew<CR>
    snoremap  <silent> <C-n> <C-o>:<C-u>confirm enew<CR>

    " <C-o>: Open file
    inoremap  <silent> <C-o> <C-o>:browse confirm e<CR>
    snoremap  <silent> <C-o> <C-o>:<C-u>browse confirm e<CR>

    " <C-s>: Save file
    inoremap  <silent> <C-s> <C-o>:w<CR>
    snoremap  <silent> <C-s> <C-o>:<C-u>w<CR>

    " <M-S-s>: Save As
    inoremap  <silent> <M-S-s> <C-o>:browse confirm saveas<CR>
    snoremap  <silent> <M-S-s> <C-o>:<C-u>browse confirm saveas<CR>

    " <C-q>: Quit
    inoremap  <silent> <C-q> <C-o>:confirm qa<CR>
    snoremap  <silent> <C-q> <C-o>:<C-u>confirm qa<CR>
	
endfunction


