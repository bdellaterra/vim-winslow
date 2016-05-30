" File:			winslow.vim
" Description:	Enhanced easy mode for Vim
" Author:		Brian Dellatera <github.com/bdellaterra>
" Version:		0.1.1
" License:      Copyright 2015 Brian Dellaterra. This file is part of Winslow.
" 				Distributed under the terms of the GNU Lesser General Public License.
"				See the file LICENSE or <http://www.gnu.org/licenses/>.


" Guard against repeat sourcing of this script
if exists('g:loaded_winslowPlugin')
	finish
end
let g:loaded_winslowPlugin = 1

" TODO: Use a timestamp or similar to handle multiple simultaneous instances
" of this plugin being used. Files, globals, and script variables will need
" updating. Consider repurposing s:easyModeIsActive to hold numeric id.

" Set directory where temporary files can be stored
" Defaults to 'vim' folder at the system temp path. A trailing slash is included.
" NOTE: Forward slashes work on both Windows and Unix-bases systems.
if !exists('g:winslow#TmpDir')
	if has('Unix')
		if exists('$TMPDIR') 
			let g:winslow#TmpDir = substitute($TMPDIR, '\v.{-}\zs(/)?$', '/vim/', '')
		else
			let g:winslow#TmpDir = '/var/tmp/vim/'
		endif
	elseif has('Windows') && exists('$TEMP') 
		let g:winslow#TmpDir = substitute($TEMP, '\v.{-}\zs(\\)?$', '\\vim\\', '')
	else
		let g:winslow#TmpDir = './.vim/tmp/'
	end
end

" File to backup current configuration before settings are applied
if !exists('g:winslow#easyModeTeardownFile')
	let g:winslow#easyModeTeardownFile = g:winslow#TmpDir . 'easyModeTeardown.exrc'
endif

" List of commands that help undo easy mode settings
if !exists('s:easyTeardown')
    let s:easyTeardown = []
endif

" Boolean indicating whether easy mode settings are active or not
if !exists('s:easyModeIsActive')
    let s:easyModeIsActive = 0
endif

" Trigger for temporarily escaping from easy mode to run a single command.
" Default is leader followed by 'n'. (mnemonic 'n' for 'normal')
" Insert mode becomes normal mode. Select mode becomes visual mode.
" Returns to insert mode automatically when the command is finished.
if !exists('g:winslow#normalModeLeader')
    exe "let g:winslow#normalModeLeader = '<leader>n'"
endif

" Trigger for running Ex commands from easy mode.
" Default is leader followed by the normal Ex command key ':'.
if !exists('g:winslow#commandModeLeader')
    exe "let g:winslow#commandModeLeader = '<leader>:'"
endif

" Trigger for switching between normal and easy/insert mode.
" Default is leader followed by 'm'. (mnemonic 'm' for 'mode')
" This is also used to switch from select mode to visual mode
"
" Trigger for escaping from easy mode to run multiple commands.
" Default is leader followed by 'm'. (mnemonic 'm' for 'mode')
" Insert mode becomes normal mode. Select mode becomes visual mode.
" Does not return to insert mode unti this mapping is invoked again.
if !exists('g:winslow#easyModeSwitch')
    let g:winslow#easyModeSwitch = '<Leader>m'
    let g:winslow#easyModeSwitchHint = '<Leader>m'  " This is the hint next to the menu entry
endif

" Boolean indicating whether easy mode switch should remain active
" after easy mode is toggled off. 
" NOTE: Even if this is set to 1 the switch is not activated until easy mode
" is activated. Call winslow#MapEasyModeSwitch() to activate it beforehand.
if !exists('g:winslow#easyModeSwitchIsPersistent')
    let g:winslow#easyModeSwitchIsPersistent = 1
endif


" Adds reset for current state of a Vim setting to the teardown cmds
function! s:AddTeardownSetting( setting )
    " Record command to restore current setting
    let s:easyTeardown += 
		\ [ 'let &' . a:setting . "="
		\   . "'" 
		\   . substitute( eval( '&' . a:setting ), "'", "''", '' ) 
		\   . "'" ]
endfunction


" Returns corresponding unmap command for a given map command.
" map - a map command without the rhs (right hand side)
function! s:UnmapCommand( map )
    " Generate unmap command by eliminating 'nore' and adding 'un'
    " TODO: This has not been fully verified
    let unmap_cmd = substitute( a:map, '^\w\+\zsnore', '', '' ) 
    let unmap_cmd = substitute( a:map, '^[^m]\?\zs\%(nore\)\?\ze', 'un', '' )
    return unmap_cmd
endfunction


" Adds reset for current state of a Vim mapping to the teardown cmds
" map - a map command without the rhs (right hand side)
"       displays the current mapping or 'No mapping found'
function! s:AddTeardownMapping( map )
    " Redirect output of map query to a variable
    redir => map_state
    exe a:map
    redir END
    " If no mapping found...
    if map_state =~ '^\_s*No mapping found\_s*$'
		" Record unmap command to reset default mapping
		let s:easyTeardown += [ s:UnmapCommand(a:map) ]
    endif
	" ...Otherwise the non-default mapping should be saved/restored via the
	" exrc file 'g:winslow#easyModeTeardownFile'. (Nothing else required here)
endfunction


" Fix for right-click moving cursor one character to the right
function! s:RightClickCursorFix()
	if col('.') > 1
		return "\<Right>"
	else
		return ''
	endif
endfunction


" NOTE: Using <SID> in function names so they can be called from a mapping. (See :help <SID>)

" Select all text in buffer
function! <SID>SelectAll()
    " Checking &slm so select mode will work properly. (See :help slm)
    exe "normal! gg" . (&slm == "" ? "VG" : "gH\<C-o>G")
endfunction


" Fix for idiosyncracies with paste mode
function! <SID>PasteFix()
    let save_paste = &paste
	let &paste = 1
    normal `[v`]:s:^\s\+::g
	let &paste = save_paste
endfunction


" Fix for idiosyncracies with pasting in over selcted text
" TODO: See if global vars can be avoided (Need something usable in mappings)
function! <SID>VisualModePasteFix()
    " NOTE: ==# is like == but case-sensitive
    if g:VisualMode ==# 'v'
		let g:VisualModePaste = 'P'
		return 0
    elseif g:VisualMode ==# 'V'
		let @* = substitute( @*, '\n$', '', '' )
		let g:VisualModePaste = 'P'
    endif
endfunction


" Function to setup easy mode configurations, while also preparing an
" exrc file to undo them
function! winslow#ActivateEasyMode()

    " Make a backup of current settings and mappings (see :help mkexrc)
    exe 'mkexrc! ' . fnameescape(g:winslow#easyModeTeardownFile)

	" Use select mode instead of visual mode
	call s:AddTeardownSetting('selectmode')
	set selectmode=mouse,key,cmd

	" Use insert mode instead of normal mode
	call s:AddTeardownSetting('insertmode')
	set insertmode

	" Right-click should place cursor
	call s:AddTeardownMapping('imap <RightMouse>')
	inoremap <silent> <RightMouse> <LeftMouse><RightMouse><C-r>=<SID>RightClickCursorFix()<CR>

	" Move by lines as displayed on screen, not as defined by line-breaks
	call s:AddTeardownMapping('map <Up>')
	call s:AddTeardownMapping('imap <Up>')
	call s:AddTeardownMapping('vmap <Up>')
	call s:AddTeardownMapping('smap <Up>')
	noremap <Up> g<Up>
	inoremap <Up> <C-o>g<Up>
	vnoremap <Up> <C-o>g<Up>
	snoremap <Up> <C-\><C-g>g<Up>

	call s:AddTeardownMapping('map <Down>')
	call s:AddTeardownMapping('imap <Down>')
	call s:AddTeardownMapping('vmap <Down>')
	call s:AddTeardownMapping('smap <Down>')
	noremap <Down> g<Down>
	inoremap <Down> <C-o>g<Down>
	vnoremap <Down> <C-o>g<Down>
	snoremap <Down> <C-\><C-g>g<Down>

	" Fix select mode cursor movement
	call s:AddTeardownMapping('smap <Left>')
	call s:AddTeardownMapping('smap <Right>')
	call s:AddTeardownMapping('smap <Home>')
	call s:AddTeardownMapping('smap <End>')
	call s:AddTeardownMapping('smap <PageUp>')
	call s:AddTeardownMapping('smap <PageDown>')
	snoremap <Left> <C-\><C-g>
	snoremap <Right> <C-\><C-n>a
	snoremap <Home> <C-\><C-g><Home>
	snoremap <End> <C-\><C-g><End>
	snoremap <PageUp> <C-\><C-g><PageUp>
	snoremap <PageDown> <C-\><C-g><PageDown>

	" If shift is pressed, cursor movement controls text selection
	call s:AddTeardownMapping('imap <S-Up>')
	call s:AddTeardownMapping('imap <S-Down>')
	call s:AddTeardownMapping('imap <S-Left>')
	call s:AddTeardownMapping('imap <S-Right>')
	call s:AddTeardownMapping('imap <S-Home>')
	call s:AddTeardownMapping('imap <S-End>')
	call s:AddTeardownMapping('imap <S-PageUp>')
	call s:AddTeardownMapping('imap <S-PageDown>')
	inoremap <S-Up> <C-o>gh<Up>
	inoremap <S-Down> <C-o>gh<Down>
	inoremap <S-Left> <Left><C-o>gh
	inoremap <S-Right> <C-o>gh
	inoremap <S-Home> <Left><C-o>gh<Home>
	inoremap <S-End> <C-o>gh<End>
	inoremap <S-PageUp> <C-o>gh<PageUp>
	inoremap <S-PageDown> <C-o>gh<PageDown>

	call s:AddTeardownMapping('smap <S-Up>')
	call s:AddTeardownMapping('smap <S-Down>')
	call s:AddTeardownMapping('smap <S-Left>')
	call s:AddTeardownMapping('smap <S-Right>')
	call s:AddTeardownMapping('smap <S-Home>')
	call s:AddTeardownMapping('smap <S-End>')
	call s:AddTeardownMapping('smap <S-PageUp>')
	call s:AddTeardownMapping('smap <S-PageDown>')
	snoremap <S-Up> <C-o><Up>
	snoremap <S-Down> <C-o><Down>
	snoremap <S-Left> <C-o><Left>
	snoremap <S-Right> <C-o><Right>
	snoremap <S-Home> <C-o><Home>
	snoremap <S-End> <C-o><End>
	snoremap <S-PageUp> <C-o><PageUp>
	snoremap <S-PageDown> <C-o><PageDown>

	" If alt is pressed, do the same thing as shift does
	" (Some terminals have problems with Shift-key combinations)
	call s:AddTeardownMapping('imap <M-Up>')
	call s:AddTeardownMapping('imap <M-Down>')
	call s:AddTeardownMapping('imap <M-Left>')
	call s:AddTeardownMapping('imap <M-Right>')
	call s:AddTeardownMapping('imap <M-Home>')
	call s:AddTeardownMapping('imap <M-End>')
	call s:AddTeardownMapping('imap <M-PageUp>')
	call s:AddTeardownMapping('imap <M-PageDown>')
	imap <M-Up> <S-Up>
	imap <M-Down> <S-Down>
	imap <M-Left> <S-Left>
	imap <M-Right> <S-Right>
	imap <M-Home> <S-Home>
	imap <M-End> <S-End>
	imap <M-PageUp> <S-PageUp>
	imap <M-PageDown> <S-PageDown>

	call s:AddTeardownMapping('smap <M-Up>')
	call s:AddTeardownMapping('smap <M-Down>')
	call s:AddTeardownMapping('smap <M-Left>')
	call s:AddTeardownMapping('smap <M-Right>')
	call s:AddTeardownMapping('smap <M-Home>')
	call s:AddTeardownMapping('smap <M-End>')
	call s:AddTeardownMapping('smap <M-PageUp>')
	call s:AddTeardownMapping('smap <M-PageDown>')
	smap <M-Up> <S-Up>
	smap <M-Down> <S-Down>
	smap <M-Left> <S-Left>
	smap <M-Right> <S-Right>
	smap <M-Home> <S-Home>
	smap <M-End> <S-End>
	smap <M-PageUp> <S-PageUp>
	smap <M-PageDown> <S-PageDown>

    " Delete unwanted keymaps that conflict w. select mode
    " (Teardown exrc file should record any previous mappings)
	if !exists('g:winslow#DisableKeymapsToImproveSelectMode') || !g:winslow#DisableKeymapsToImproveSelectMode
	    silent! sunmap <S-q>
	    silent! sunmap %
	endif

    " Trigger for running a single normal command from easy mode
    call s:AddTeardownMapping( 'imap ' . g:winslow#normalModeLeader )
    call s:AddTeardownMapping( 'smap ' . g:winslow#normalModeLeader )
    exe 'inoremap ' . g:winslow#normalModeLeader . ' <C-o>'
    exe 'snoremap ' . g:winslow#normalModeLeader . ' <C-o>'

    " Trigger for running Ex commands from easy mode
    call s:AddTeardownMapping( 'imap ' . g:winslow#commandModeLeader )
    call s:AddTeardownMapping( 'smap ' . g:winslow#commandModeLeader )
    exe 'inoremap ' . g:winslow#commandModeLeader . ' <C-o>:'
    exe 'snoremap ' . g:winslow#commandModeLeader . ' <C-o>:'

    " Switch for toggling easy mode on and off
    call s:AddTeardownMapping( 'map ' . g:winslow#easyModeSwitch )
    call s:AddTeardownMapping( 'imap ' . g:winslow#easyModeSwitch )
	call winslow#MapEasyModeSwitch()
	exe 'amenu <silent> 5.10 &Easy.&Toggle\ Easy\ Mode'
		\ . (exists('g:winslow#easyModeSwitchHint') ? '<Tab>' . g:winslow#easyModeSwitchHint : '')
		\ . ' ' . g:winslow#easyModeSwitch
	" cunmenu &Easy.&Toggle\ Easy\ Mode
    " amenu <silent> 5.9000 &Easy.&Deactivate\ Easy\ Mode
	" 	\ :silent! call winslow#DeactivateEasyMode(0)<CR>


    " FILE MAPPINGS

    " <C-n>: Create new file
    call s:AddTeardownMapping( 'imap <C-n>' )
    call s:AddTeardownMapping( 'smap <C-n>' )
    inoremap  <silent> <C-n> <C-o>:confirm enew<CR>
    snoremap  <silent> <C-n> <C-o>:<C-u>confirm enew<CR>
    inoremenu <silent> 5.100 &Easy.&New<Tab>Ctrl+n <C-o>:confirm enew<CR>
    snoremap  <silent> 5.100 &Easy.&New<Tab>Ctrl+n <C-o>:<C-u>confirm enew<CR>

    " <C-o>: Open file
    call s:AddTeardownMapping( 'imap <C-o>' )
    call s:AddTeardownMapping( 'smap <C-o>' )
    inoremap  <silent> <C-o> <C-o>:browse confirm e<CR>
    snoremap  <silent> <C-o> <C-o>:<C-u>browse confirm e<CR>
    inoremenu <silent> 5.200 &Easy.&Open<Tab>Ctrl+o <C-o>:browse confirm e<CR>
    snoremenu <silent> 5.200 &Easy.&Open<Tab>Ctrl+o <C-o>:<C-u>browse confirm e<CR>

    " <C-s>: Save file
    call s:AddTeardownMapping( 'imap <C-s>' )
    call s:AddTeardownMapping( 'smap <C-s>' )
    inoremap  <silent> <C-s> <C-o>:w<CR>
    snoremap  <silent> <C-s> <C-o>:<C-u>w<CR>
    inoremenu <silent> 5.300 &Easy.&Save<Tab>Ctrl+s <C-o>:w<CR>
    snoremenu <silent> 5.300 &Easy.&Save<Tab>Ctrl+s <C-o>:<C-u>w<CR>

    " <M-S-s>: Save As
    call s:AddTeardownMapping( 'imap <M-S-s>' )
    call s:AddTeardownMapping( 'smap <M-S-s>' )
    inoremap  <silent> <M-S-s> <C-o>:browse confirm saveas<CR>
    snoremap  <silent> <M-S-s> <C-o>:<C-u>browse confirm saveas<CR>
    inoremenu <silent> 5.400 &Easy.Save\ &As<Tab>Alt+Shift+s <C-o>:browse confirm saveas<CR>
    snoremenu <silent> 5.400 &Easy.Save\ &As<Tab>Alt+Shift+s <C-o>:<C-u>browse confirm saveas<CR>

    " <C-q>: Quit
    call s:AddTeardownMapping( 'imap <C-q>' )
    call s:AddTeardownMapping( 'smap <C-q>' )
    inoremap  <silent> <C-q> <C-o>:confirm qa<CR>
    snoremap  <silent> <C-q> <C-o>:<C-u>confirm qa<CR>
    inoremenu <silent> 5.500 &Easy.&Quit<Tab>Ctrl+q <C-o>:confirm qa<CR>
    snoremenu <silent> 5.500 &Easy.&Quit<Tab>Ctrl+q <C-o>:<C-u>confirm qa<CR>

    "  EDIT MAPPINGS

    " <C-z>: Undo
    call s:AddTeardownMapping( 'imap <C-z>' )
    call s:AddTeardownMapping( 'smap <C-z>' )
    inoremap  <silent> <C-z> <C-o>:undo<CR>
    snoremap  <silent> <C-z> <C-o>:<C-u>undo<CR>
    inoremenu <silent> 5.600 &Easy.&Undo<Tab>Ctrl+z <C-o>:undo<CR>
    snoremenu <silent> 5.600 &Easy.&Undo<Tab>Ctrl+z <C-o>:<C-u>undo<CR>

    " <C-y>: Redo
    call s:AddTeardownMapping( 'imap <C-y>' )
    call s:AddTeardownMapping( 'smap <C-y>' )
    inoremap  <silent> <C-y> <C-o>:redo<CR>
    snoremap  <silent> <C-y> <C-o>:<C-u>redo<CR>
    inoremenu <silent> 5.700 &Easy.&Redo<Tab>Ctrl+y <C-o>:redo<CR>
    snoremenu <silent> 5.700 &Easy.&Redo<Tab>Ctrl+y <C-o>:<C-u>redo<CR>

    " <C-x>: Cut
    call s:AddTeardownMapping( 'imap <C-x>' )
    call s:AddTeardownMapping( 'smap <C-x>' )
    inoremap  <silent> <C-x> <C-o>:normal V"+xi<CR>
    snoremap  <silent> <C-x> <C-\><C-n>:normal `<v`>"+xi<CR><C-\><C-g>
    inoremenu <silent> 5.800 &Easy.Cu&t<Tab>Ctrl+x <C-o>:normal V"+xi<CR>
    snoremenu <silent> 5.800 &Easy.Cu&t<Tab>Ctrl+x <C-\><C-n>:normal `<v`>"+xi<CR><C-\><C-g>

    " <C-c>: Copy
    call s:AddTeardownMapping( 'imap <C-c>' )
    call s:AddTeardownMapping( 'smap <C-c>' )
    inoremap  <silent> <C-c> <C-o>:normal V"+y<CR>
    snoremap  <silent> <C-c> <C-\><C-n>:normal `<v`>"+y<CR><C-\><C-g>
    inoremenu <silent> 5.900 &Easy.&Copy<Tab>Ctrl+c <C-o>:normal V"+y<CR>
    snoremenu <silent> 5.900 &Easy.&Copy<Tab>Ctrl+c <C-\><C-n>:normal `<v`>"+y<CR><C-\><C-g>

    " <C-v>: Paste
    call s:AddTeardownMapping( 'imap <C-v>' )
    call s:AddTeardownMapping( 'smap <C-v>' )
    inoremap  <silent> <C-v> <C-o>:let save_ve=&ve<CR><C-o>:set ve=onemore<CR><C-o>"+gP<C-\><C-n>`]<C-\><C-n>a<C-o>:let &ve=save_ve<CR>
    snoremap  <silent> <C-v> <C-o>:<C-u>:let g:VisualMode = visualmode() \| call <SID>VisualModePasteFix()<CR>:exe 'normal gv"+g' . g:VisualModePaste<CR><C-o>:call <SID>PasteFix()<CR><C-o>:unlet g:VisualMode<CR><C-\><C-n>`]<C-\><C-n>a
    inoremenu <silent> 5.1000 &Easy.&Paste<Tab>Ctrl+v <C-o>:let save_ve=&ve<CR><C-o>:set ve=onemore<CR><C-o>"+gP<C-\><C-n>`]<C-\><C-n>a<C-o>:let &ve=save_ve<CR>
    snoremenu <silent> 5.1000 &Easy.&Paste<Tab>Ctrl+v <C-o>:<C-u>:let g:VisualMode = visualmode() \| call <SID>VisualModePasteFix()<CR>:exe 'normal gv"+g' . g:VisualModePaste<CR><C-o>:call <SID>PasteFix()<CR><C-o>:unlet g:VisualMode<CR><C-\><C-n>`.<C-\><C-n>a

    " <C-a>: Select All
    call s:AddTeardownMapping( 'imap <C-a>' )
    call s:AddTeardownMapping( 'smap <C-a>' )
    inoremap  <silent> <C-a> <C-o>:call <SID>SelectAll()<CR>
    snoremap  <silent> <C-a> <C-o>:<C-u>call <SID>SelectAll()<CR>
    inoremenu <silent> 5.1100 &Easy.Select\ Al&l<Tab>Ctrl+a <C-o>:call <SID>SelectAll()<CR>
    snoremenu <silent> 5.1100 &Easy.Select\ Al&l<Tab>Ctrl+a <C-o>:<C-u>call <SID>SelectAll()<CR>


    " Append additional teardown commands to the exrc file
    call writefile( s:easyTeardown, 
		\ fnameescape(g:winslow#easyModeTeardownFile) )

    " Set flag indicating easy mode is active
    let s:easyModeIsActive = 1
	
endfunction


" Undo easy mode configurations
" Optional 1st arg will unmap persistent easy mode switch if zero.
function! winslow#DeactivateEasyMode( ... )

    let persistentSwitch = get(a:000, 0, g:winslow#easyModeSwitchIsPersistent)

	if !persistentSwitch
		call winslow#UnmapEasyModeSwitch()
	endif

    " Restore previous settings and mappings from backup
    exe 'source ' . fnameescape(g:winslow#easyModeTeardownFile)

    " Delete the backup file
    call delete(fnameescape(g:winslow#easyModeTeardownFile))

    " Set flag indicating easy mode is not active
    let s:easyModeIsActive = 0

	" Remove the Easy menu
	aunmenu Easy

endfunction


" Toggle easy mode configurations on/off
function! winslow#ToggleEasyMode()
	if exists('s:easyModeIsActive') && s:easyModeIsActive
		silent! call winslow#DeactivateEasyMode()
	else
		silent! call winslow#ActivateEasyMode()
	endif
endfunction

" Setup keymap to switch in/out of easy mode behavior
" If persistent flag is set the mapping will still remain in effect
" after easy mode is toggled off
function! winslow#MapEasyModeSwitch()
	let s:unmapEasyModeSwitch = []    " list to save unmap commands
	if exists('g:winslow#easyModeSwitch')
		if g:winslow#easyModeSwitchIsPersistent
			let s:unmapEasyModeSwitch = [ 
					\ s:UnmapCommand('map ' . g:winslow#easyModeSwitch),
					\ s:UnmapCommand('imap ' . g:winslow#easyModeSwitch),
					\ s:UnmapCommand('vmap ' . g:winslow#easyModeSwitch),
					\ s:UnmapCommand('smap ' . g:winslow#easyModeSwitch,
					\ ]
			exe 'noremap <silent> ' . g:winslow#easyModeSwitch . ' :call winslow#ToggleEasyMode()<CR>'
			exe 'inoremap <silent> ' . g:winslow#easyModeSwitch . ' <C-o>:call winslow#ToggleEasyMode()<CR>'
			exe 'vnoremap <silent> ' . g:winslow#easyModeSwitch . ' <C-\><C-n>:call winslow#ToggleEasyMode()<CR><C-\><C-n>gv'
			exe 'snoremap <silent> ' . g:winslow#easyModeSwitch . ' <C-g><C-\><C-n>:call winslow#ToggleEasyMode()<CR><C-\><C-n>gv'
		endif
	endif
endfunction

" Clear mappings for the easy mode switch
function! winslow#UnmapEasyModeSwitch()
	if exists('s:unmapEasyModeSwitch')
		   \ && type('s:unmapEasyModeSwitch') == type([])
		   \ && len(s:unmapEasyModeSwitch) > 0
		for s in s:unmapEasyModeSwitch
			exe s
		endfor
	endif
endfunction

