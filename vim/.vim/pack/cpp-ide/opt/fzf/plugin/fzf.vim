" vim:ts=2:sw=2:noet

let s:log_level = 0

" Default configuration
let s:fzf_config = {
			\ 'get_files_cmd': 'git ls-files --recurse-submodules',
			\ 'file_list_file': '',
			\ 'very_magic': 1,
			\ 'ignore_case': 1,
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
				\ 'dirty': 3,
				\ 'files': [],
				\ 'get_files_cmd': get(cfg, 'get_files_cmd', s:fzf_config.get_files_cmd),
				\ 'file_list_file': s:calculate_flf_path(cfg),
				\ 'paths': [],
				\ 'globs': {'incl': [], 'excl': []},
				\ 'very_magic': get(cfg, 'very_magic', s:fzf_config.very_magic),
				\ 'ignore_case': get(cfg, 'ignore_case', s:fzf_config.ignore_case),
				\ 'nul_separate_paths' : get(cfg, 'nul_separate_paths', s:fzf_config.very_magic)
				\ }

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
	fu! cache.build_file_list_cmd()
		" TODO: Put the map in a lambda.
		let iglobs = self.globs.incl
					\ ->mapnew({i, s -> '-g ' . shellescape(s)})->join()
		let eglobs = self.globs.excl
					\ ->mapnew({i, s -> '-g ' . shellescape('!' . s)})->join()
		let paths = self.paths
					\ ->mapnew({i, s -> shellescape(s)})->join()
		return printf('rg --files %s %s %s %s',
					\ self.ignore_case ? '--glob-case-insensitive' : '',
					\ iglobs,
					\ eglobs,
					\ paths)
	endfu
	fu! cache.refresh(...) closure
		let force = a:0 && a:1
		call s:Log("Refreshing cache force=%s dirty=%s...", force, self.dirty)
		if force || self.dirty
			" Get the file list
			let get_files_cmd = self.build_file_list_cmd()
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
		let self.globs.incl = []
		let self.globs.excl = []
	endfu
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
	fu! cache.add_globs(type, ...) closure
		let self.globs[a:type] = self.globs[a:type]->extend(
			\ a:000[:]->filter({idx, patt -> self.globs[a:type]->index(patt) < 0}))
		let self.dirty = 1
	endfu
	fu! cache.remove_globs(type, bang, ...) closure
		let self.dirty = 1
		if (!a:0)
			if a:bang
				" Remove all patterns of specified type
				let self.globs[a:type] = []
			else
				echoerr "Must provide at least one glob if <bang> is not provided."
			endif
		else
			" Remove patterns provided as input.
			let self.globs[a:type] = self.globs[a:type]->filter({
						\ glob -> a:000->index(glob) >= 0 })
		endif
		let self.dirty = 1
	endfu
	return cache
endfu

let TEST = 0
if TEST
	let c = s:create_fzf_cache('ls')
	echo "Adding paths for ^C and ^D but excluding [SR] and W"
	call c.add_paths('incl', '^C', '^D')
	call c.add_paths('excl', '[SR]', 'W')
	echo c
	echo "-----refresh()"
	echo c.refresh()
	echo "Adding patt for ^NTUSER"
 	call c.add_paths('incl', '^NTUSER')
	echo "-----refresh()"
	echo c.refresh()
endif

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

" TODO: Consider completion of submodule names.
com -nargs=* Show echo !empty(<q-args>) ? [<f-args>]
			\ ->filter({idx, val -> val != 'files' })
			\ ->map({idx, val -> s:fcache[val]}) : s:fcache
com -bang RebuildCache 
			\ call s:fcache().destroy() |
			\ let s:fcache = s:create_fzf_cache()
com -bang ClearCache call s:fcache().clear()
com ClearFilters call s:fcache().clear_filters()
com -nargs=+ AddPaths call s:fcache().add_paths(<f-args>)
com -bang -nargs=* RemovePaths call s:fcache.remove_paths(<bang>0, <f-args>)
com -nargs=+ AddInclGlobs call s:fcache().add_globs('incl', <f-args>)
com -nargs=+ AddExclGlobs call s:fcache.add_globs('excl', <f-args>)
com -bang -nargs=* RemoveInclGlobs call s:fcache.remove_globs('incl', <bang>0, <f-args>)
com -bang -nargs=* RemoveExclGlobs call s:fcache.remove_globs('excl', <bang>0, <f-args>)
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

