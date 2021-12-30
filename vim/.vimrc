" Include some default settings from the Vim example.
" Note: Intentionally not doing 'behave mswin'
set nocompatible
source $VIMRUNTIME/vimrc_example.vim

" Allow jumping to buffer in other window with :sb
set switchbuf=useopen

" Disable menu and toolbar.
set guioptions-=m
set guioptions-=T
set modelines&
set modeline
set incsearch
" hls is annoying to me, especially for small, common text strings.
set nohls
set mouse=a

" Comma is marginally easier to hit than backslash.
"let maplocalleader = ','

set formatoptions=tcqro
" j is a useful addition (obviates need to delete comment leaders after
" joining lines) but not universally available...
silent! set formatoptions+=j

" Don't leave backup files lying around
set nobackup

if has('persistent_undo')
	set undofile
	set undodir=~/.vimundo,.
endif

" TODO: Perhaps a chooser function that considers term/gui, even
" differentiating between different terminals, for which I may use different
" (terminal) colorschemes.
colorscheme default

" This should be the Vim default, but isn't...
filetype plugin indent on
syntax enable

" Set some configuration variables with implications for plugins.

" Intellisense/code completion
let g:cfg_completion_plugin = 'ycm'

" Specify a directory for plugins
" - For Neovim: stdpath('data') . '/plugged'
" - Avoid using standard Vim directory names like 'plugin'
call plug#begin('~/.vim/plugged')

" Make sure you use single quotes
Plug 'bpstahlman/txtfmt', { 'frozen': 1 }
Plug 'bpstahlman/vim-sexp', { 'frozen': 1 }

" vim-lsp (language server platform)
if g:cfg_completion_plugin == 'vim-lsp'
	Plug 'prabirshrestha/async.vim'
	Plug 'prabirshrestha/vim-lsp'
elseif g:cfg_completion_plugin == 'ycm'
	Plug 'ycm-core/YouCompleteMe', { 'do': './install.py --clangd-completer' }
endif

" Full path fuzzy file, buffer, mru, tag, ... finder for Vim
"Plug 'kien/ctrlp'

Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

Plug 'easymotion/vim-easymotion'
" Caveat: This plugin supersedes vim-multiple-cursors, which has serious
" issues with undo/redo and is no longer maintained.
Plug 'mg979/vim-visual-multi', {'branch': 'master'}

" Shorthand notation; fetches https://github.com/junegunn/vim-easy-align
"Plug 'junegunn/vim-easy-align'

" Any valid git URL is allowed
"Plug 'https://github.com/junegunn/vim-github-dashboard.git'

" Multiple Plug commands can be written in a single line using | separators
"Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'

" On-demand loading
"Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
"Plug 'tpope/vim-fireplace', { 'for': 'clojure' }

" Using a non-default branch
"Plug 'rdnetto/YCM-Generator', { 'branch': 'stable' }

" Using a tagged release; wildcard allowed (requires git 1.9.2 or above)
"Plug 'fatih/vim-go', { 'tag': '*' }

" Plugin options
"Plug 'nsf/gocode', { 'tag': 'v.20150303', 'rtp': 'vim' }

" Plugin outside ~/.vim/plugged with post-update hook
"Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }

" Unmanaged plugin (manually installed and updated)
"Plug '~/my-prototype-plugin'

" Initialize plugin system
call plug#end()

" Easymotion
map <Space> <Plug>(easymotion-prefix)

" Easymotion setup

" Design Decision: Plugin author recommends using `nmap' for overwin versions
" of standard commands. I don't like this because overwin can slow down the
" common case of searching in current window. My solution is to double the
" leading space for overwin.
map <space><space>w <Plug>(easymotion-overwin-w)
map <space><space>W <Plug>(easymotion-overwin-W)
map <space><space>w <Plug>(easymotion-overwin-w)
map <space><space>W <Plug>(easymotion-overwin-W)
 
<Plug>(easymotion-f) | <Leader>f{char}
<Plug>(easymotion-F) | <Leader>F{char}
<Plug>(easymotion-t) | <Leader>t{char}
<Plug>(easymotion-T) | <Leader>T{char}
<Plug>(easymotion-w) | <Leader>w
<Plug>(easymotion-W) | <Leader>W
<Plug>(easymotion-b) | <Leader>b
<Plug>(easymotion-B) | <Leader>B
<Plug>(easymotion-e) | <Leader>e
<Plug>(easymotion-E) | <Leader>E
<Plug>(easymotion-ge)| <Leader>ge
<Plug>(easymotion-gE)| <Leader>gE
<Plug>(easymotion-j) | <Leader>j
<Plug>(easymotion-k) | <Leader>k
<Plug>(easymotion-n) | <Leader>n
<Plug>(easymotion-N) | <Leader>N
<Plug>(easymotion-s) | <Leader>s

" Single-line versions of f/F/t/T/s
" Note: s is bidir version of f/F
map <M-s> <Plug>(easymotion-sl)
map <M-f> <Plug>(easymotion-fl)
map <M-F> <Plug>(easymotion-Fl)
map <M-t> <Plug>(easymotion-tl)
map <M-T> <Plug>(easymotion-Tl)

let g:EasyMotion_startofline = 0 " keep cursor column when JK motion

" Try to get sensible cursor shape in a terminal.
if &term =~ '^xterm\|rxvt'
  " blinking vertical bar
  let &t_SI .= "\<Esc>[5 q"
  " solid underscore
  let &t_SR .= "\<Esc>[4 q"
  " solid block
  let &t_EI .= "\<Esc>[2 q"
  " 1 or 0 -> blinking block
  " 3 -> blinking underscore
  " Recent versions of xterm (282 or above) also support
  " 5 -> blinking vertical bar
  " 6 -> solid vertical bar
endif

if g:cfg_completion_plugin == 'vim-lsp'
	" If clangd is available, install autocommands that will configure Vim's omni
	" completion to use it (via the vim-lsp plugin).
	" Copied from Jonas Devlieghere's vim-lsp-clangd page:
	" https://jonasdevlieghere.com/vim-lsp-clangd/
	let g:lsp_log_verbose = 1
	let g:lsp_log_file = '/tmp/vim-lsp.log'
	if executable('clangd')
		augroup lsp_clangd
			autocmd!
			autocmd User lsp_setup call lsp#register_server({
						\ 'name': 'clangd',
						\ 'cmd': {server_info->['clangd']},
						\ 'whitelist': ['c', 'cpp', 'objc', 'objcpp'],
						\ })
			autocmd FileType c setlocal omnifunc=lsp#complete
			autocmd FileType cpp setlocal omnifunc=lsp#complete
			autocmd FileType objc setlocal omnifunc=lsp#complete
			autocmd FileType objcpp setlocal omnifunc=lsp#complete
		augroup end
	endif
elseif g:cfg_completion_plugin == 'ycm'
endif

" Allow use of meta keys in terminals.
" Explanation: When Vim processes a map lhs such as <M-j>, it converts it to
" <Esc>j. But the terminal code received for a pressed <M-j> will actually be
" metafied j, which needs to be converted to <Esc>j for the mapping to work.
" Caveat: The following won't work in terminals:
" <M-[> <M->>
" Note that while <M-[> makes sense due to its use in terminal escape
" sequences, I'm not sure why <M->> doesn't work.
set <M-F>=F
set <M-f>=f
set <M-H>=H
set <M-h>=h
set <M-J>=J
set <M-j>=j
set <M-k>=k
set <M-K>=K
set <M-b>=b
set <M-w>=w
set <M-g>=g
set <M-e>=e
set <M-N>=N
set <M-n>=n
set <M-,>=,
set <M-.>=.
set <M-=>==
set <M-->=-
set <M-I>=I
set <M-A>=A
set <M-@>=@
set <M-?>=?
set <M-C>=C
set <M-c>=c
set <M-O>=O
set <M-o>=o
set <M-L>=L
set <M-h>=h
set <M-l>=l
set <M-s>=s
set <M-S>=S
set <M-t>=t
set <M-T>=T
set <M-p>=p
set <M-P>=P

finish

" -- FZF Customization --
" Pull in the basic fzf vim support (which is required for fzf.vim plugin).
set rtp+=~/.fzf

" -- Simple project support: ctags, cscope, grep --
" TODO: This may be obsoleted by the fzf/ripgrep stuff...
" Pre-requisite: For each project tag provided to the Prj command, PATH must
" contain an executable named gen-<tag>-files, which writes a list of project
" files to stdout.
fu! s:bldtags(...)
	silent !>cscope.files
	for prj in a:000
		silent exe '!gen-' . prj . '-files >cscope.files'
	endfor
	silent !ctags -L cscope.files 2>/dev/null
	silent !cscope -bR 2>/dev/null
	set grepprg=xargs\ <cscope.files\ grep\ -n\ $*
	cs kill -1
	silent cs add cscope.out
endfu
com! -nargs=+ Prj call s:bldtags(<f-args>) | normal! <C-L>
" Note: My own fzf setup is in ~/.vim/bundle/fzf-bps

" Command for git grep
" - fzf#vim#grep(command, with_column, [options], [fullscreen])
command! -bang -nargs=* GGrep
  \ call fzf#vim#grep('git grep --line-number '.shellescape(<q-args>), 0, <bang>0)

" Override Colors command. You can safely do this in your .vimrc as fzf.vim
" will not override existing commands.
command! -bang Colors
  \ call fzf#vim#colors({'left': '15%', 'options': '--reverse --margin 30%,0'}, <bang>0)

" Augmenting Ag command using fzf#vim#with_preview function
"   * fzf#vim#with_preview([[options], preview window, [toggle keys...]])
"     * For syntax-highlighting, Ruby and any of the following tools are required:
"       - Highlight: http://www.andre-simon.de/doku/highlight/en/highlight.php
"       - CodeRay: http://coderay.rubychan.de/
"       - Rouge: https://github.com/jneen/rouge
"
"   :Ag  - Start fzf with hidden preview window that can be enabled with "?" key
"   :Ag! - Start fzf in fullscreen and display the preview window above
command! -bang -nargs=* Ag
  \ call fzf#vim#ag(<q-args>,
  \                 <bang>0 ? fzf#vim#with_preview('up:60%')
  \                         : fzf#vim#with_preview('right:50%:hidden', '?'),
  \                 <bang>0)

" Similarly, we can apply it to fzf#vim#grep. To use ripgrep instead of ag:
command! -bang -nargs=* Rg
  \ call fzf#vim#grep(
  \   'rg --column --line-number --no-heading --color=always '.<q-args>, 1,
  \   <bang>0 ? fzf#vim#with_preview('up:60%')
  \           : fzf#vim#with_preview('right:50%:hidden', '?'),
  \   <bang>0)

" Likewise, Files command with preview window
command! -bang -nargs=? -complete=dir Files
  \ call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)

"fu! s:stringify_fzf_args(...)
"	return join(map(copy(a:000), 'shellescape(v:val)'), ' ')
"endfu
"
"" Similarly, we can apply it to fzf#vim#grep. To use ripgrep instead of ag:
"fu! s:stringify_fzf_args(...)
"	"return join(map(copy(a:000), 'shellescape(v:val)'), ' ')
"	return join(a:000, ' ')
"endfu

" Slimv
let g:paredit_disable_lisp = 1
"let g:slimv_impl = 'sbcl'
let g:slimv_lisp = '/usr/bin/sbcl'
let g:slimv_swank_cmd = '! xterm -e sbcl --load /home/bstahlman/.vim/bundle/slimv/slime/start-swank.lisp &'
"let g:slimv_impl = 'clisp'
"let g:slimv_lisp = '/usr/bin/clisp'
"let g:slimv_swank_cmd = '! SWANK_PORT=4005 xterm -iconic -e "/usr/bin/clisp" -i "/home/bstahlman/.vim/bundle/slimv/slime/start-swank.lisp" &

" Vim-sexp

" Timeouts
" Rationale: By default, ttimeout is disabled (-1), which can cause problems
" (eg) if you hit <Esc> in insert mode and hit another key (eg w or b) within
" timeoutlen (default 1s). The solution is to specify a shorter timeout for
" key codes.
" Note: 'timeoutlen' will still be used for mappings, but 'ttimeoutlen'
" determines (eg) whether <Esc>b is <Esc> followed by b or <M-b>.
" Note: It's not necessary to set 'ttimeout' when 'timeout' is set.
set ttimeoutlen=100

" Note: For now, keeping all, in case I want to override some more.
" Eventually, keep only the overridden entries.
" TODO: Consider whether to use the <Plug>(...) mapping method instead. The
" advantage is that it would permit me to create multiple mappings to the same
" command.
" Single-key mappings: h, l, H, L
" IMPORTANT TODO: I've temporarily disabled the maps because 'meta' was
" causing a noticeable delay whenever I hit Esc in a terminal. The problem is
" that Vim converts a map for (eg) <M-x> to \ex, which means Vim must wait the
" map timeout before concluding the <Esc> is not part of a map.
let g:which_maps = 'single-key-expert'
let g:sexp_mode_toggle = '<C-K>'
let g:sexp_mode_escape = ','
let g:sexp_mode_initial_state = 0
" TEMP DEBUG
"au BufEnter *.* echomsg "Mapping ,s" | nmap <buffer> ,s :echo ",s"<CR>
"au BufEnter *.* nmap <buffer> ,s :echo ",s"<CR>
"au BufEnter *.* nmap <buffer> ,h :echo ",h"<CR>
"au BufEnter *.* nmap <buffer> h :echo "h"<CR>
if which_maps == 'meta'
	" Note: So far, I like meta or single-key-expert best, but with meta,
	" there's not a lot of need for sexp mode...
	" Note: On Ubuntu, menu mappings preclude use of metafied keys for maps
	" used in operator pending mode.
let g:sexp_mappings = {
    \ 'sexp_outer_list':                'af',
    \ 'sexp_inner_list':                'if',
    \ 'sexp_outer_top_list':            'aF',
    \ 'sexp_inner_top_list':            'iF',
    \ 'sexp_outer_string':              'as',
    \ 'sexp_inner_string':              'is',
    \ 'sexp_outer_element':             'ae',
    \ 'sexp_inner_element':             'ie',
    \ 'sexp_outer_child_tail':          'aC',
    \ 'sexp_outer_child_head':          'ac',
    \ 'sexp_inner_child_tail':          'iC',
    \ 'sexp_inner_child_head':          'ic',
    \ 'sexp_move_to_prev_bracket':      '(',
    \ 'sexp_move_to_next_bracket':      ')',
    \ 'sexp_move_to_prev_element_head': 'B',
    \ 'sexp_move_to_next_element_head': 'W',
    \ 'sexp_move_to_prev_element_tail': 'gE',
    \ 'sexp_move_to_next_element_tail': 'E',
    \ 'sexp_flow_to_prev_close':        '<M-J>',
    \ 'sexp_flow_to_next_open':         '<M-j>',
    \ 'sexp_flow_to_prev_open':         '<M-k>',
    \ 'sexp_flow_to_next_close':        '<M-K>',
    \ 'sexp_flow_to_prev_leaf_head':    '<M-b>',
    \ 'sexp_flow_to_next_leaf_head':    '<M-w>',
    \ 'sexp_flow_to_prev_leaf_tail':    '<M-g>',
    \ 'sexp_flow_to_next_leaf_tail':    '<M-e>',
    \ 'sexp_move_to_prev_top_element':  '<M-N>',
    \ 'sexp_move_to_next_top_element':  '<M-n>',
    \ 'sexp_select_prev_element':       '<M-,>',
    \ 'sexp_select_next_element':       '<M-.>',
    \ 'sexp_indent':                    '==',
    \ 'sexp_indent_top':                '=-',
    \ 'sexp_indent_and_clean':          '<M-=>',
    \ 'sexp_indent_and_clean_top':      '<M-->',
    \ 'sexp_round_head_wrap_list':      ',(',
    \ 'sexp_round_tail_wrap_list':      ',)',
    \ 'sexp_square_head_wrap_list':     ',[',
    \ 'sexp_square_tail_wrap_list':     ',]',
    \ 'sexp_curly_head_wrap_list':      ',{',
    \ 'sexp_curly_tail_wrap_list':      ',}',
    \ 'sexp_round_head_wrap_element':   'g(',
    \ 'sexp_round_tail_wrap_element':   'g)',
    \ 'sexp_square_head_wrap_element':  'g[',
    \ 'sexp_square_tail_wrap_element':  'g]',
    \ 'sexp_curly_head_wrap_element':   'g{',
    \ 'sexp_curly_tail_wrap_element':   'g}',
    \ 'sexp_insert_at_list_head':       '<M-I>',
    \ 'sexp_insert_at_list_tail':       '<M-A>',
    \ 'sexp_splice_list':               '<M-@>',
    \ 'sexp_convolute':                 '<M-?>',
    \ 'sexp_clone_list':                '<LocalLeader>C',
    \ 'sexp_clone_list_sl':             '<LocalLeader><LocalLeader>C',
    \ 'sexp_clone_element':             '<LocalLeader>c',
    \ 'sexp_clone_element_sl':          '<LocalLeader><LocalLeader>c',
    \ 'sexp_raise_list':                '<M-O>',
    \ 'sexp_raise_element':             '<M-o>',
    \ 'sexp_swap_list_backward':        '<M-H>',
    \ 'sexp_swap_list_forward':         '<M-L>',
    \ 'sexp_swap_element_backward':     '<M-h>',
    \ 'sexp_swap_element_forward':      '<M-l>',
    \ 'sexp_emit_head_element':         '<M-P>',
    \ 'sexp_emit_tail_element':         '<M-p>',
    \ 'sexp_capture_prev_element':      '<M-T>',
    \ 'sexp_capture_next_element':      '<M-t>',
\ }

elseif which_maps == 'meta-expert'
let g:sexp_mappings = {
    \ 'sexp_outer_list':                '<>af',
    \ 'sexp_inner_list':                '<>if',
    \ 'sexp_outer_top_list':            '<>aF',
    \ 'sexp_inner_top_list':            '<>iF',
    \ 'sexp_outer_string':              '<>as',
    \ 'sexp_inner_string':              '<>is',
    \ 'sexp_outer_element':             '<>ae',
    \ 'sexp_inner_element':             '<>ie',
    \ 'sexp_move_to_prev_bracket':      '(',
    \ 'sexp_move_to_next_bracket':      ')',
    \ 'sexp_move_to_prev_element_head': 'b',
    \ 'sexp_move_to_next_element_head': 'w',
    \ 'sexp_move_to_prev_element_tail': 'ge',
    \ 'sexp_move_to_next_element_tail': 'e',
    \ 'sexp_flow_to_prev_close':        '<><M-J>',
    \ 'sexp_flow_to_next_open':         '<><M-j>',
    \ 'sexp_flow_to_prev_open':         '<><M-k>',
    \ 'sexp_flow_to_next_close':        '<><M-K>',
    \ 'sexp_flow_to_prev_leaf_head':    'B',
    \ 'sexp_flow_to_next_leaf_head':    'W',
    \ 'sexp_flow_to_prev_leaf_tail':    'gE',
    \ 'sexp_flow_to_next_leaf_tail':    'E',
    \ 'sexp_move_to_prev_top_element':  'N',
    \ 'sexp_move_to_next_top_element':  'n',
    \ 'sexp_select_prev_element':       '<',
    \ 'sexp_select_next_element':       '>',
    \ 'sexp_indent':                    'm',
    \ 'sexp_indent_top':                'M',
    \ 'sexp_round_head_wrap_list':      '<M-r>',
    \ 'sexp_round_tail_wrap_list':      '<M-R>',
    \ 'sexp_square_head_wrap_list':     '<M-[>',
    \ 'sexp_square_tail_wrap_list':     '<M-]>',
    \ 'sexp_curly_head_wrap_list':      '<M-{>',
    \ 'sexp_curly_tail_wrap_list':      '<M-}>',
    \ 'sexp_round_head_wrap_element':   'r',
    \ 'sexp_round_tail_wrap_element':   'R',
    \ 'sexp_square_head_wrap_element':  '[',
    \ 'sexp_square_tail_wrap_element':  ']',
    \ 'sexp_curly_head_wrap_element':   '{',
    \ 'sexp_curly_tail_wrap_element':   '}',
    \ 'sexp_insert_at_list_head':       'I',
    \ 'sexp_insert_at_list_tail':       'A',
    \ 'sexp_splice_list':               '@',
    \ 'sexp_convolute':                 '<C-@>',
    \ 'sexp_raise_list':                '<M-O>',
    \ 'sexp_raise_element':             '<M-o>',
    \ 'sexp_swap_list_backward':        '<M-h>',
    \ 'sexp_swap_list_forward':         '<M-l>',
    \ 'sexp_swap_element_backward':     '<C-h>',
    \ 'sexp_swap_element_forward':      '<C-l>',
    \ 'sexp_emit_head_element':         '<M-{>',
    \ 'sexp_emit_tail_element':         '<M-}>',
    \ 'sexp_capture_prev_element':      '<M-[>',
    \ 'sexp_capture_next_element':      '<M-]>',
    \ }
elseif which_maps == 'single-key-expert'
	let g:sexp_mappings = {
    \ 'sexp_outer_list':                '<>af',
    \ 'sexp_inner_list':                '<>if',
    \ 'sexp_outer_top_list':            '<>aF',
    \ 'sexp_inner_top_list':            '<>iF',
    \ 'sexp_outer_string':              '<>as',
    \ 'sexp_inner_string':              '<>is',
    \ 'sexp_outer_element':             '<>ae',
    \ 'sexp_inner_element':             '<>ie',
    \ 'sexp_move_to_prev_bracket':      'q',
    \ 'sexp_move_to_next_bracket':      'p',
    \ 'sexp_move_to_prev_element_head': 'b',
    \ 'sexp_move_to_next_element_head': 'w',
    \ 'sexp_move_to_prev_element_tail': '<M-e>',
    \ 'sexp_move_to_next_element_tail': 'e',
    \ 'sexp_flow_to_prev_close':        'h',
    \ 'sexp_flow_to_next_open':         'g',
    \ 'sexp_flow_to_prev_open':         'G',
    \ 'sexp_flow_to_next_close':        'H',
    \ 'sexp_flow_to_prev_leaf_head':    'B',
    \ 'sexp_flow_to_next_leaf_head':    'W',
    \ 'sexp_flow_to_prev_leaf_tail':    '<M-E>',
    \ 'sexp_flow_to_next_leaf_tail':    'E',
    \ 'sexp_move_to_prev_top_element':  'Q',
    \ 'sexp_move_to_next_top_element':  'P',
    \ 'sexp_select_prev_element':       '<',
    \ 'sexp_select_next_element':       '>',
    \ 'sexp_indent':                    'm',
    \ 'sexp_indent_top':                'M',
    \ 'sexp_round_head_wrap_list':      '<M-(>',
    \ 'sexp_round_tail_wrap_list':      '<M-)>',
    \ 'sexp_square_head_wrap_list':     '<M-[>',
    \ 'sexp_square_tail_wrap_list':     '<M-]>',
    \ 'sexp_curly_head_wrap_list':      '<M-{>',
    \ 'sexp_curly_tail_wrap_list':      '<M-}>',
    \ 'sexp_round_head_wrap_element':   '(',
    \ 'sexp_round_tail_wrap_element':   ')',
    \ 'sexp_square_head_wrap_element':  '[',
    \ 'sexp_square_tail_wrap_element':  ']',
    \ 'sexp_curly_head_wrap_element':   '{',
    \ 'sexp_curly_tail_wrap_element':   '}',
    \ 'sexp_insert_at_list_head':       'I',
    \ 'sexp_insert_at_list_tail':       'i',
    \ 'sexp_splice_list':               '!',
    \ 'sexp_convolute':                 '@',
    \ 'sexp_raise_list':                'R',
    \ 'sexp_raise_element':             'r',
    \ 'sexp_swap_list_backward':        'S',
    \ 'sexp_swap_list_forward':         'L',
    \ 'sexp_swap_element_backward':     's',
    \ 'sexp_swap_element_forward':      'l',
    \ 'sexp_emit_head_element':         'A',
    \ 'sexp_emit_tail_element':         '"',
    \ 'sexp_capture_prev_element':      'a',
    \ 'sexp_capture_next_element':      '''',
    \ }

endif

" IMPORTANT TODO: Need to decide on a more flexible strategy, which can work
" for multiple projects/project types. Note that I'm in the process of
" migrating to an approach built on top of fzf/ripgrep.

" -- Grep --
let pats = ['*.c', '*.h', '*.S', '*.s', '*.asm', '*.mk', 'Makefile']
let incs = map(copy(pats), "'--include=''' . v:val . ''''")
let &grepprg = 'grep -Rn ' . join(incs) . ' $* .'

" -- Ctags --
" Look upwards to the nearest tags-global file.
" Priority: Prefer local files and files in dir of current file.
" TODO: Perhaps add HOME stop dir...
set tags=./tags,tags,./tags-global;,tags-global;

" Rebuild local tags only.
" Note: Extra CR gets rid of the 'Hit Enter...' prompt.
nmap ,t :!(cd %:p:h; ctags *.[ch])&<CR><CR>

" -- Virtual clipboard --
" Explanation: Can't easily copy between gvim and console vim running in tmux.
" These commands provide simple way to do it using netrw with scp protocol.
" Usage:
" In source:
"   :Cbc
"   Note: Range is optional, defaults to current line.
" In destination
"   :Cbp root@stahlman-vm2
com! -range Cbc <line1>,<line2>w! /tmp/cb.txt
" TODO: Get more sophisticated with args (e.g., default user to root, perhaps
" provide way to cache hostname).
com! -nargs=1 Cbp r scp://<args>//tmp/cb.txt

" -- Cscope --
if has("cscope")
	" -- BPS Stuff --
	fu! s:find_and_attach_cscope(bang)
		" Look upwards for the nearest global cscope db.
		" Caveat! May want to check both cwd and directory of current file (in
		" case we get jumped out of the project structure).
		" Caveat: For now, just give .; or ; with no stop dir.
		" TODO: Understand why Vim's upward search with stopdir seems buggy.
		let paths = ['.', '']
		for path in paths
			let db = findfile('cscope-global.out', path . ';')
			if !empty(db)
				break
			endif
		endfor
		if empty(db)
			echoerr "Can't find global cscope db to attach to! Run bldcs from the root of the project."
			return
		endif
		if a:bang == '!'
			exe 'cs kill -1'
		endif
		exe 'cs add ' . db
	endfu

	" Add bang to kill existing connections, omit bang to append.
	com! -nargs=0 -bang CSadd :call s:find_and_attach_cscope("<bang>")

	" Use quickfix (without appending) for everything.
	set cscopequickfix=s-,c-,d-,i-,t-,e-
	" Search cscope db before tags.
	set csto=0
	" Use :cstag for normal tag commands.
	set cst


	" -- Jason Duell's cscope mappings --
	""""""""""""" My cscope/vim key mappings
	"
	" The following maps all invoke one of the following cscope search types:
	"
	"   's'   symbol: find all references to the token under cursor
	"   'g'   global: find global definition(s) of the token under cursor
	"   'c'   calls:  find all calls to the function name under cursor
	"   't'   text:   find all instances of the text under cursor
	"   'e'   egrep:  egrep search for the word under cursor
	"   'f'   file:   open the filename under cursor
	"   'i'   includes: find files that include the filename under cursor
	"   'd'   called: find functions that function under cursor calls
	"
	" Below are three sets of the maps: one set that just jumps to your
	" search result, one that splits the existing vim window horizontally and
	" diplays your search result in the new window, and one that does the same
	" thing, but does a vertical split instead (vim 6 only).
	"
	" I've used CTRL-\ and CTRL-@ as the starting keys for these maps, as it's
	" unlikely that you need their default mappings (CTRL-\'s default use is
	" as part of CTRL-\ CTRL-N typemap, which basically just does the same
	" thing as hitting 'escape': CTRL-@ doesn't seem to have any default use).
	" If you don't like using 'CTRL-@' or CTRL-\, , you can change some or all
	" of these maps to use other keys.  One likely candidate is 'CTRL-_'
	" (which also maps to CTRL-/, which is easier to type).  By default it is
	" used to switch between Hebrew and English keyboard mode.
	"
	" All of the maps involving the <cfile> macro use '^<cfile>$': this is so
	" that searches over '#include <time.h>" return only references to
	" 'time.h', and not 'sys/time.h', etc. (by default cscope will return all
	" files that contain 'time.h' as part of their name).


	" To do the first type of search, hit 'CTRL-\', followed by one of the
	" cscope search types above (s,g,c,t,e,f,i,d).  The result of your cscope
	" search will be displayed in the current window.  You can use CTRL-T to
	" go back to where you were before the search.  
	"

	nmap <C-\>s :cs find s <C-R>=expand("<cword>")<CR><CR>	
	nmap <C-\>g :cs find g <C-R>=expand("<cword>")<CR><CR>	
	nmap <C-\>c :cs find c <C-R>=expand("<cword>")<CR><CR>	
	nmap <C-\>t :cs find t <C-R>=expand("<cword>")<CR><CR>	
	nmap <C-\>e :cs find e <C-R>=expand("<cword>")<CR><CR>	
	nmap <C-\>f :cs find f <C-R>=expand("<cfile>")<CR><CR>	
	nmap <C-\>i :cs find i ^<C-R>=expand("<cfile>")<CR>$<CR>
	nmap <C-\>d :cs find d <C-R>=expand("<cword>")<CR><CR>	


	" Using 'CTRL-spacebar' (intepreted as CTRL-@ by vim) then a search type
	" makes the vim window split horizontally, with search result displayed in
	" the new window.
	"
	" (Note: earlier versions of vim may not have the :scs command, but it
	" can be simulated roughly via:
	"    nmap <C-@>s <C-W><C-S> :cs find s <C-R>=expand("<cword>")<CR><CR>	

	nmap <C-@>s :scs find s <C-R>=expand("<cword>")<CR><CR>	
	nmap <C-@>g :scs find g <C-R>=expand("<cword>")<CR><CR>	
	nmap <C-@>c :scs find c <C-R>=expand("<cword>")<CR><CR>	
	nmap <C-@>t :scs find t <C-R>=expand("<cword>")<CR><CR>	
	nmap <C-@>e :scs find e <C-R>=expand("<cword>")<CR><CR>	
	nmap <C-@>f :scs find f <C-R>=expand("<cfile>")<CR><CR>	
	nmap <C-@>i :scs find i ^<C-R>=expand("<cfile>")<CR>$<CR>	
	nmap <C-@>d :scs find d <C-R>=expand("<cword>")<CR><CR>	


	" Hitting CTRL-space *twice* before the search type does a vertical 
	" split instead of a horizontal one (vim 6 and up only)
	"
	" (Note: you may wish to put a 'set splitright' in your .vimrc
	" if you prefer the new window on the right instead of the left

	nmap <C-@><C-@>s :vert scs find s <C-R>=expand("<cword>")<CR><CR>
	nmap <C-@><C-@>g :vert scs find g <C-R>=expand("<cword>")<CR><CR>
	nmap <C-@><C-@>c :vert scs find c <C-R>=expand("<cword>")<CR><CR>
	nmap <C-@><C-@>t :vert scs find t <C-R>=expand("<cword>")<CR><CR>
	nmap <C-@><C-@>e :vert scs find e <C-R>=expand("<cword>")<CR><CR>
	nmap <C-@><C-@>f :vert scs find f <C-R>=expand("<cfile>")<CR><CR>	
	nmap <C-@><C-@>i :vert scs find i ^<C-R>=expand("<cfile>")<CR>$<CR>	
	nmap <C-@><C-@>d :vert scs find d <C-R>=expand("<cword>")<CR><CR>


	""""""""""""" key map timeouts
	"
	" By default Vim will only wait 1 second for each keystroke in a mapping.
	" You may find that too short with the above typemaps.  If so, you should
	" either turn off mapping timeouts via 'notimeout'.
	"
	"set notimeout 
	"
	" Or, you can keep timeouts, by uncommenting the timeoutlen line below,
	" with your own personal favorite value (in milliseconds):
	"
	"set timeoutlen=4000
	"
	" Either way, since mapping timeout settings by default also set the
	" timeouts for multicharacter 'keys codes' (like <F1>), you should also
	" set ttimeout and ttimeoutlen: otherwise, you will experience strange
	" delays as vim waits for a keystroke after you hit ESC (it will be
	" waiting to see if the ESC is actually part of a key code like <F1>).
	"
	"set ttimeout 
	"
	" personally, I find a tenth of a second to work well for key code
	" timeouts. If you experience problems and have a slow terminal or network
	" connection, set it higher.  If you don't set ttimeoutlen, the value for
	" timeoutlent (default: 1000 = 1 second, which is sluggish) is used.
	"
	"set ttimeoutlen=100
endif

" --- Txtfmt / Journal ---
" Using with .jnl files
" Function: Jnl_configure_txtfmt()
" Description: Set buffer-local txtfmt options just before txtfmt plugins are
" loaded. The intent is for this routine to be called from a BufRead,BufNewFile
" autocommand.
fu! Jnl_configure_txtfmt()
	" Note: The following tokrange setting will be used only if there is no
	" txtfmt modeline. Generally, this will be only when the .jnl file is first
	" created (if ever).
	"let b:txtfmtTokrange = '180s'
	set enc=utf8
	let b:txtfmtTokrange = '0xE000s'
	" Make sure I don't see map ambiguity warnings every time I open a journal
	" file
	"let g:txtfmtMapwarn = "MoOcC"
	" Note: The jnl filetype is normally set as follows:
	" set ft=jnl.txtfmt
	" Currently, one of the jnl maps conflicts with Txtfmt's \ga.
	" TODO: Eventually, need to fix this, but for now, get rid of the warning
	" altogether:
	let g:txtfmtMapwarn = 'cC'
endfu

" TODO: Consider having both pre and post local vimrcs.
if filereadable('~/.vimrc.local')
	so ~/.vimrc.local
endif

augroup TxtfmtInNotes
au!
au FileType * if expand("<amatch>") == "notes" | setlocal ft=notes.txtfmt | endif
augroup END

" TEMP DEBUG
fu! s:Get_synstack()
	for id in synstack(line("."), col("."))
	   echo synIDattr(id, "name")
	endfor
endfu
nmap <F8> :call <SID>Get_synstack()<CR>

" vim:ts=4:sw=4:tw=78
