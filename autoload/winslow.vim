" File:			winslow.vim
" Description:	Enhanced easy mode for Vim
" Author:		Brian Dellatera <github.com/bdellaterra>
" Version:		0.1.1
" License:      Copyright 2015 Brian Dellaterra. This file is part of Winslow.
" 				Distributed under the terms of the GNU Lesser General Public License.
"				See the file LICENSE or <http://www.gnu.org/licenses/>.


" Set directory where temporary files can be stored.
" Defaults to 'vim' folder at the system temp path
" (trailing forward slash included - forward slashes work on both unix and windows)
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
		let g:winslow#TmpDir = './.vim/tmp/'    " Forward slashes work on Windows
	end
end

" File to backup current configuration before custom settings are applied
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

" Leader for easy mode. This will trigger normal mode leader commands.
" Default is the normal leader pressed twice. 
if !exists('g:winslow#easyModeLeader')
    let g:winslow#easyModeLeader = '<Leader><Leader>'
endif

" Trigger for running Ex commands in easy mode.
" Default is leader followed by the normal command key.
if !exists('g:winslow#easyModeCommandLeader')
    exe "let g:winslow#easyModeCommandLeader = '<leader>:'"
endif

" Trigger for temporarily escaping Easy/insert mode to run a single normal mode
" command. Default is the Escape key
" Vim's native Control-O mapping for this behavior is another option.
if !exists('g:winslow#easyModeEscapeLeader')
    let g:winslow#easyModeEscapeLeader = '<Esc>'
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
"       that when executed returns the current mapping or 'No mapping found'
function! s:UnmapCommand( map )
    " Generate unmap command by eliminating 'nore' and adding 'un'
    " TODO: This has not been fully verified
    let unmap_cmd = substitute( a:map, '^\w\+\zsnore', '', '' ) 
    let unmap_cmd = substitute( a:map, '^[^m]\?\zs\%(nore\)\?\ze', 'un', '' )
    return unmap_cmd
endfunction


" Adds reset for current state of a Vim mapping to the teardown cmds
" map - a map command without the rhs (right hand side)
"       that when executed returns the current mapping or 'No mapping found'
function! s:AddTeardownMapping( map )
    " Redirect output of map query to a variable
    redir => map_state
    exe a:map
    redir END
    " If no mapping found...
    if map_state =~ '^\_s*No mapping found\_s*$'
		" Record unmap command to reset default mapping
		let s:easyTeardown += [ s:UnmapCommand(map_state) ]
    endif
    " ...Otherwise the non-default mapping should have been recorded to the
    " initial exrc file that was auto-generated.
	let g:test = s:easyTeardown
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
    exe "normal! gg" . (&slm == "" ? "VG" : "gH\<C-O>G")
endfunction


" Fix for idiosyncracies with paste mode
" TODO: Find another way to fix without re-indenting
function! <SID>PasteFix()
    normal `[v`]:s:^\s\+::g
    normal gv=
endfunction


" Fix for idiosyncracies with pasting in over selcted text
" TODO: See if global vars can be avoided
function! <SID>VisualModePasteFix()
    " NOTE: ==# is like == but case-sensitive
    if g:VisualMode ==# 'v'
		let g:VisualModePaste = 'P'
		return 0
    elseif g:VisualMode ==# 'V'
		" let g:Test = localtime()
		let @* = substitute( @*, '\n$', '', '' )
		let g:VisualModePaste = 'P'
    endif
endfunction


" Function to setup custom easy mode configurations, and also prep an
" exrc file to undo them
function! winslow#ActivateCustomEasyMode()

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
    inoremap <silent> <RightMouse> <LeftMouse><RightMouse><C-R>=<SID>RightClickCursorFix()<CR>
    " Nullify Ctrl+LeftMouse since it's easy to hit accidentally and not used in
    " this configuration
    " TODO: Investigate how this affects ctags
	if !exists('g:winslow#DisableCtrlLeftMouse') || !g:winslow#DisableCtrlLeftMouse
		call s:AddTeardownMapping('nmap <C-LeftMouse>')
		call s:AddTeardownMapping('map  <C-LeftMouse>')
		call s:AddTeardownMapping('imap <C-LeftMouse>')
		call s:AddTeardownMapping('nmap <C-2-LeftMouse>')
		call s:AddTeardownMapping('map  <C-2-LeftMouse>')
		call s:AddTeardownMapping('imap <C-2-LeftMouse>')
		call s:AddTeardownMapping('nmap <C-3-LeftMouse>')
		call s:AddTeardownMapping('map  <C-3-LeftMouse>')
		call s:AddTeardownMapping('imap <C-3-LeftMouse>')
		call s:AddTeardownMapping('nmap <C-4-LeftMouse>')
		call s:AddTeardownMapping('map  <C-4-LeftMouse>')
		call s:AddTeardownMapping('imap <C-4-LeftMouse>')
		nmap <C-LeftMouse> <LeftMouse>
		map  <C-LeftMouse> <LeftMouse>
		imap <C-LeftMouse> <LeftMouse>
		nmap <C-2-LeftMouse> <2-LeftMouse>
		map  <C-2-LeftMouse> <2-LeftMouse>
		imap <C-2-LeftMouse> <2-LeftMouse>
		nmap <C-3-LeftMouse> <3-LeftMouse>
		map  <C-3-LeftMouse> <3-LeftMouse>
		imap <C-3-LeftMouse> <3-LeftMouse>
		nmap <C-4-LeftMouse> <4-LeftMouse>
		map  <C-4-LeftMouse> <4-LeftMouse>
		imap <C-4-LeftMouse> <4-LeftMouse>
	endif

    " Delete unwanted keymaps that conflict w. select mode
    " (Teardown exrc file should record any previous mappings)
	if !exists('g:winslow#DisableKeymapsToImproveSelectMode') || !g:winslow#DisableKeymapsToImproveSelectMode
	    silent! sunmap <S-Q>
	    silent! sunmap %
	endif

    " Easy mode trigger for normal-mode leader commands.
    call s:AddTeardownMapping( 'imap ' . g:winslow#easyModeLeader )
    call s:AddTeardownMapping( 'smap ' . g:winslow#easyModeLeader )
    exe 'imap ' . g:winslow#easyModeLeader . ' <C-\><C-n><Leader>'
    exe 'smap ' . g:winslow#easyModeLeader . ' <C-o><Leader>'

    " Trigger for running Ex commands from easy mode
    call s:AddTeardownMapping( 'imap ' . g:winslow#easyModeCommandLeader )
    call s:AddTeardownMapping( 'smap ' . g:winslow#easyModeCommandLeader )
    exe 'inoremap ' . g:winslow#easyModeCommandLeader . ' <C-o>:'
    exe 'snoremap ' . g:winslow#easyModeCommandLeader . ' <C-o>:'

    " Trigger for temporarily escaping insert mode to run a single normal mode command
    call s:AddTeardownMapping( 'imap ' . g:winslow#easyModeEscapeLeader )
    exe 'inoremap ' . g:winslow#easyModeEscapeLeader . ' <C-o>'
	" DISABLED: <Esc> in select mode should probably just cancel text selection
    " call s:AddTeardownMapping( 'smap ' . g:winslow#easyModeEscapeLeader )
    " exe 'snoremap ' . g:winslow#easyModeEscapeLeader . ' <C-o>'
	
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
    snoremap  <silent> <C-x> <C-\><C-N>:normal `<v`>"+xi<CR><C-\><C-G>
    inoremenu <silent> 5.800 &Easy.Cu&t<Tab>Ctrl+x <C-o>:normal V"+xi<CR>
    snoremenu <silent> 5.800 &Easy.Cu&t<Tab>Ctrl+x <C-\><C-N>:normal `<v`>"+xi<CR><C-\><C-G>

    " <C-c>: Copy
    call s:AddTeardownMapping( 'imap <C-c>' )
    call s:AddTeardownMapping( 'smap <C-c>' )
    inoremap  <silent> <C-c> <C-o>:normal V"+y<CR>
    snoremap  <silent> <C-c> <C-\><C-N>:normal `<v`>"+y<CR><C-\><C-G>
    inoremenu <silent> 5.900 &Easy.&Copy<Tab>Ctrl+c <C-o>:normal V"+y<CR>
    snoremenu <silent> 5.900 &Easy.&Copy<Tab>Ctrl+c <C-\><C-N>:normal `<v`>"+y<CR><C-\><C-G>

    " <C-v>: Paste
    call s:AddTeardownMapping( 'imap <C-v>' )
    call s:AddTeardownMapping( 'smap <C-v>' )
    inoremap  <silent> <C-v> <C-o>:let save_ve=&ve<CR><C-O>:set ve=onemore<CR><C-O>"+gP<C-\><C-N>`]<C-\><C-N>a<C-O>:let &ve=save_ve<CR>
    snoremap  <silent> <C-v> <C-O>:<C-U>:let g:VisualMode = visualmode() \| call <SID>VisualModePasteFix()<CR>:exe 'normal gv"+g' . g:VisualModePaste<CR><C-O>:call <SID>PasteFix()<CR>:unlet g:VisualMode<CR><C-\><C-N>`]<C-\><C-N>a
    inoremenu <silent> 5.1000 &Easy.&Paste<Tab>Ctrl+v <C-o>:let save_ve=&ve<CR><C-O>:set ve=onemore<CR><C-O>"+gP<C-\><C-N>`]<C-\><C-N>a<C-O>:let &ve=save_ve<CR>
    snoremenu <silent> 5.1000 &Easy.&Paste<Tab>Ctrl+v <C-O>:<C-U>:let g:VisualMode = visualmode() \| call <SID>VisualModePasteFix()<CR>:exe 'normal gv"+g' . g:VisualModePaste<CR><C-O>:call <SID>PasteFix()<CR>:unlet g:VisualMode<CR><C-\><C-N>`]<C-\><C-N>a

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


" Undo custom easy mode configurations
function! winslow#DeactivateCustomEasyMode()

    " Restore previous settings and mappings from backup
    exe 'source ' . fnameescape(g:winslow#easyModeTeardownFile)

    " Delete the backup file
    call delete(fnameescape(g:winslow#easyModeTeardownFile))

	" TODO: Find out why this seems necessary to restore normal <Esc> behavior
	iunmap <Esc>

    " Set flag indicating easy mode is not active
    let s:easyModeIsActive = 0

	" Remove the Easy menu
	aunmenu Easy

endfunction


" Toggle custom easy mode configurations on/off
function! winslow#ToggleCustomEasyMode()

	if exists('s:easyModeIsActive') && s:easyModeIsActive
		silent! call winslow#DeactivateCustomEasyMode()
	else
		silent! call winslow#ActivateCustomEasyMode()
	endif

endfunction

