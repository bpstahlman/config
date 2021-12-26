" vim:ts=2:sw=2:noet

let s:log_level = 0

" Default configuration
let s:fzf_config = {
			\ 'file_list_file': '',
			\ 'very_magic': 1,
			\ 'ignore_glob_case': 1,
			\ 'ignore_case': 0,
			\ 'nul_separate_paths': 1
\ }

fu! s:calculate_flf_path(cfg)
	let flf_path = a:cfg->get('file_list_file', '')
	if !empty(flf_path)
		if !empty(flf_path->glob())
			if !flf_path->filewritable()
				echoerr "Can't overwrite existing file (or directory)!"
			endif
		else
			" File doesn't exist. Check parent dir.
			if !expand(flf_path, '%h')->filewritable()
				echoerr "Can't write to directory containing specified file!"
			endif
		endif
		" Save the path to file we should be able to write.
		let flf = {'user': 1, 'path': flf_path}
	else
		" Generate tempfile
		let flf = {'user': 0, 'path': tempname()}
	endif
	return flf
endfu

fu! Dummy(ch)
endfu

fu! s:create_fzf_cache(...)
	let cfg = get(g:, 'fzf_config', {})

	" TODO: Put options under opts or something.
	" TODO: Don't need dict for file_list_file.
	let cache = {
				\ 'dirty': 1,
				\ 'files': [],
				\ 'file_list_file': s:calculate_flf_path(cfg),
				\ 'paths': [],
				\ 'globs': [],
				\ 'very_magic': get(cfg, 'very_magic', s:fzf_config.very_magic),
				\ 'ignore_glob_case': get(cfg, 'ignore_glob_case', s:fzf_config.ignore_glob_case),
				\ 'ignore_case': get(cfg, 'ignore_case', s:fzf_config.ignore_case),
				\ 'nul_separate_paths' : get(cfg, 'nul_separate_paths', s:fzf_config.very_magic),
				\ 'clean' : {}
				\ }

	" Display the cache.
	fu! cache.show_cache(bang) closure
		echo "Cache is" self.dirty ? "dirty" : "clean"
		echo "file list:" self.file_list_file
		echo "file listing command:" self.get_files_cmd()
		echo "paths:" self.paths
		echo "globs:" self.globs
		echo printf("options: ignore_glob_case=%s ignore_patt_case=%s",
					\ self.ignore_glob_case ? "on" : "off",
					\ self.ignore_case ? "on" : "off")
		if (a:bang)
			call self.show_methods()
		endif
	endfu
	" Note: Wish I'd known about `:function {N}' long ago...
	fu! cache.show_methods() closure
		for [key, FnOrVal] in items(self)
			if type(FnOrVal) == 2
				echo printf("%s: %s", key, function(FnOrVal))
			endif
		endfor
	endfu
	fu! cache.get_rg_cmd(...) closure
		" TODO: Use option to decide whether to use xargs or not...
		let ret = printf('xargs -0a %s'
		\   . ' rg --column --line-number --no-heading --color=always %s %s'
		\   , s:fcache.file_list_file.path
		\   , a:000->mapnew({i, p -> shellescape(p)})->join())
		call s:Log("Ripgrep command: %s", ret)
		return ret
	endfu
	fu! cache.get_edit_source_cmd() closure
		" TODO: Is nul-separation needed? I'm thinking not since xargs reads stdin...
		return 'cat ' . self.file_list_file.path
					\ . (self.nul_separate_paths ? ' | tr \\0 \\n' : '')
	endfu
	fu! cache.destroy() closure
		echomsg "Bye!"
		" Delete any temp file not belonging to user.
		" TODO: Decide how this should work...
		if !self.file_list_file.user
			if filereadable(self.file_list_file.path)
				if delete(self.file_list_file.path)
					echoerr "Unable to delete tempfile:" . self.file_list_file
				endif
			endif
		endif
	endfu
	fu! cache.get_files_cmd() closure
		if !self.dirty
			return self.clean.get_files_cmd
		endif
		" TODO: Consider just returning cache if up-to-date...
		let globs = self.globs
					\ ->mapnew({i, s -> '-g ' . shellescape(s)})->join()
		let paths = self.paths
					\ ->mapnew({i, s -> shellescape(s)})->join()
		let self.clean.get_files_cmd = printf('rg --files %s %s %s',
					\ self.ignore_glob_case ? '--glob-case-insensitive' : '',
					\ globs,
					\ paths)
		return self.clean.get_files_cmd
	endfu
	fu! cache.refresh(...) closure
		let force = a:0 && a:1
		call s:Log("Refreshing cache force=%s dirty=%s...", force, self.dirty)
		if force || self.dirty
			" Get the file list
			let get_files_cmd = self.get_files_cmd()
			call s:Log("Reading raw file list: %s", get_files_cmd)
			let self.files = get_files_cmd->systemlist()
			call s:Log("Writing file list to file: %s", self.file_list_file.path)
			call writefile(
						\ (self.nul_separate_paths
						\ ? [self.files->join("\n")]
						\ : self.files), self.file_list_file.path)
			let self.dirty = 0
		endif
	endfu
	fu! cache.clear() closure
		let self.dirty = 1
	endfu
	" TODO: Consider whether this should be combined with previous somehow...
	fu! cache.clear_filters() closure
		let self.dirty = 1
		let self.paths = []
		let self.globs = []
	endfu
	" TODO: One set of methods should handle paths and globs.
	fu! cache.add_paths(...) closure
		let self.paths = self.paths->extend(
			\ a:000[:]->filter({idx, path -> self.paths->index(path) < 0}))
		let self.dirty = 1
	endfu
	fu! cache.remove_paths(bang, ...) closure
		if (!a:0)
			if a:bang
				" Remove all paths.
				let self.paths = []
			else
				echoerr "Must provide at least one path if <bang> is not provided."
			endif
		else
			" Remove patterns provided as input.
			let self.paths = self.paths->filter({
						\ path -> a:000->index(path) >= 0 })
		endif
		let self.dirty = 1
	endfu
	" Interactive front end for glob removal
	fu! cache.remove_globs_ui() closure
		" Create list of removable globs.
		call fzf#run(fzf#wrap({
					\ 'source': self.globs[:],
					\ 'sinklist': { globs ->
					\ call(function(self.remove_globs, [0], self), globs)}}))
	endfu
	" Leading ^ means prepend.
	" Bang means clear existing
	fu! cache.add_globs(bang,...) closure
		if a:bang
			let self.globs = []
		endif
		let prepend = a:000->len() && a:000[0] == '^'
		" Append or prepend patterns not already in list.
		let self.globs = self.globs->extend(
			\ a:000[:]->filter({idx, patt -> self.globs->index(patt) < 0}),
			\ prepend ? 0 : self.globs->len())
		let self.dirty = 1
	endfu
	fu! cache.remove_globs(bang, ...) closure
		if (!a:0)
			if a:bang
				" Remove all globs.
				let self.globs = []
			else
				echoerr "Must provide at least one glob if <bang> is not provided."
			endif
		else
			" Remove globs provided as input.
			let globs = a:000
			let self.globs = self.globs->filter({
						\ i, glob -> globs->index(glob) < 0 })
			let self.dirty = 1
		endif
	endfu
	return cache
endfu

fu! Test(...)
	echomsg string(a:000)
endfu

" Create the project file cache.
" Note: May be recreated later with the <TBD>Refresh command.
let s:fcache = s:create_fzf_cache()
fu! s:fcache()
	return s:fcache
endfu
" Make sure the fcache is cleaned up at shutdown.
au! VimLeave s:fcache->destroy()

	" Map for quickly finding a file to edit.
nmap <leader>e
	\ :call <SID>fcache().refresh() \|
	\ :call fzf#run(fzf#wrap({
	\   'source': <SID>fcache().get_edit_source_cmd(),
	\   'sink': 'e'
	\ }))<cr>

nmap <leader>d
	\ : call <SID>fcache().remove_globs_ui()<cr>

" TODO: Consider completion of submodule names.
com -bang -nargs=0 Show call s:fcache().show_cache(<bang>0)
com -bang RebuildCache 
			\ call s:fcache().destroy() |
			\ let s:fcache = s:create_fzf_cache()
com -bang ClearCache call s:fcache().clear()
com ClearFilters call s:fcache().clear_filters()
com -nargs=+ AddPaths call s:fcache().add_paths(<f-args>)
com -bang -nargs=* RemovePaths call s:fcache.remove_paths(<bang>0, <f-args>)
com -bang -nargs=+ AddGlobs call s:fcache().add_globs(<bang>0, <f-args>)
com -nargs=+ RemoveGlobs call s:fcache().remove_globs(<bang>0, <f-args>)
com LoggingOn let s:log_level = 1
com LoggingOff let s:log_level = 0

command! -nargs=+ Grep
	\ :call <SID>fcache().refresh() |
	\ :call fzf#run(fzf#wrap({
	\   'source': 'xargs -0a ' . s:fcache.file_list_file.path . ' grep -E ' . <q-args>
	\   'sink': 'e'
	\ }))<cr>

" TODO: Make vim output with NULs as line sep.
" fzf --read0
" xargs -0
command! -bang -nargs=* Rg
	\ call s:fcache.refresh()
	\ | call fzf#vim#grep(s:fcache.get_rg_cmd(<f-args>),
	\   1,
  \   <bang>0 ? fzf#vim#with_preview('up:60%')
  \           : fzf#vim#with_preview('right:50%:hidden', '?'),
  \   <bang>0)

" Ancillary functions

fu! s:Log(fmt, ...)
	if s:log_level > 0
		echomsg call('printf', [a:fmt] + a:000)
	endif
endfu

let TEST = 1
if TEST
	LoggingOn
	AddGlobs gpc/** ida/**
	AddGlobs !gpc/base/ !ida/common
endif

