" My fzf vim bindings
" This is the default extra key bindings
"
function! s:build_quickfix_list(lines)
  call setqflist(map(copy(a:lines), '{ "filename": v:val }'))
  copen
  cc
endfunction

let g:fzf_action = {
  \ 'ctrl-q': function('s:build_quickfix_list'),
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

fu! s:stringify_fzf_args(...)
	return join(map(copy(a:000), 'shellescape(v:val)'), ' ')
endfu

fu! s:process_rg_lines(title, lines)
	let title = 'Search Args:' . a:title
	let cmd = remove(a:lines, 0)
	let entries = map(a:lines[:], {idx, line -> split(line, ':')})
	" NOP if no matches found.
	if empty(entries) | return | endif
	" Convert each non-empty entry to Dict
	let entries = map(filter(entries[:], {i, e -> !empty(e)}), {i, e -> {
		\ 'filename': e[0],
		\ 'lnum': e[1],
		\ 'col': e[2],
		\ 'text': join(e[3:], '')}})
	" Decide how/whether to open the first/only entry.
	" Rules:
	"   Never open multiple files.
	"   Don't open any files if <ctrl-q> was used to accept.
	"   Add to quickfix list if not opening a file for each match.
	let ocmd = cmd == 'ctrl-q'
		\ ? ''
		\ : cmd == 'ctrl-x'
			\ ? 'sp'
			\ : cmd == 'ctrl-v'
				\ ? 'vsp'
				\ : 'e'
	if len(entries) > 1 || empty(ocmd)
		" TODO: Consider having a cycle/toggle option determine where
		" the new entries should go in quickfix stack: e.g., add new,
		" add at end, replace, append, etc...
		" Note: When the optional 'what' Dict is provided, 1st arg is
		" ignored.
		call setqflist([], ' ', {'items': entries, 'title': a:title})
		if empty(ocmd)
			copen
			cc
		endif
	endif
	if !empty(ocmd)
		exe ocmd entries[0].filename
	endif
endfu

" *** COMMANDS ***
" Command: Rg
" TODO: What about the pattern?
			"\. <sid>stringify_fzf_args(<f-args>),
command! -nargs=+ -complete=dir Rgb
	\ call fzf#run(fzf#wrap(
		\{'source': 'rg --column -n --no-heading '
			\. join([<f-args>]),
		\ 'options': [
			\'--multi',
			\'--expect=ctrl-q,ctrl-t,ctrl-x,ctrl-v',
			\'--nth=4..',
			\'--bind=ctrl-a:select-all,ctrl-z:deselect-all'],
		\ 'sink*': function('<sid>process_rg_lines', [join([<f-args>], ' ')])}))

" Enable per-command history
" TODO: Decide on this...
" - History files will be stored in the specified directory
" - When set, CTRL-N and CTRL-P will be bound to 'next-history' and
"   'previous-history' instead of 'down' and 'up'.
let g:fzf_history_dir = '~/.local/share/fzf-history'


" END my own fzf.vim
