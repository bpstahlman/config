" vim:ts=2:sw=2:noet

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
				\ 'patts': {'incl': [], 'excl': []},
				\ 'globs': {'incl': [], 'excl': []},
				\ 'very_magic': get(cfg, 'very_magic', s:fzf_config.very_magic),
				\ 'ignore_case': get(cfg, 'ignore_case', s:fzf_config.ignore_case),
				\ 'nul_separate_paths' : get(cfg, 'nul_separate_paths', s:fzf_config.very_magic)
				\ }

	" FIXME: Too many %s. Decide what get_globs should return...
	fu! cache.get_rg_cmd(...) closure
		" TODO: Use option to decide whether to use xargs or not...
		let ret = printf('xargs -0a %s'
		\   . ' rg --column --line-number --no-heading --color=always %s %s'
		\   , s:fcache.file_list_file.path
		\   , s:fcache.get_globs()
		\   , a:000->join())
		echomsg "Running ripgrep: " . ret
		return ret
	endfu
	fu! cache.get_edit_source_cmd() closure
		return 'cat ' . self.file_list_file.path
					\ . (self.nul_separate_paths ? ' | tr \\0 \\n' : '')
	endfu
	fu! cache.get_globs() closure
		" FIXME: Make --glob-case-insensitive an option.
		return
					\ '--glob-case-insensitive '
					\ . self.globs.incl->mapnew('"-g ''" . v:val . "''"')->join()
					\ . self.globs.excl->mapnew('"-g ''!" . v:val . "''"')->join()
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
	fu! cache.apply_filters() closure
		" Apply (or reapply) the filter
		" !!!!!!!! UNDER CONSTRUCTION !!!!!
		let ipatts = self.patts.incl
		let epatts = self.patts.excl
		let iglobs = s:GlobsToPatts(self.globs.incl)
		let eglobs = s:GlobsToPatts(self.globs.excl)
		echomsg "iglobs: " . string(iglobs)
		call s:Log("Pre-filter: #files=%s", len(self.files))
		let self.files = self.files->filter({
					\ idx, path ->
					\ ((ipatts->empty() && iglobs->empty()) ||
					\  (!ipatts->empty() &&
					\   ipatts->s:Any(path, self.very_magic, self.ignore_case)) ||
					\  (!iglobs->empty() &&
					\   iglobs->s:Any(path, self.very_magic, self.ignore_case))) &&
					\ !((!epatts->empty() &&
					\    epatts->s:Any(path, self.very_magic, self.ignore_case)) ||
					\   (!eglobs->empty() &&
					\    eglobs->s:Any(path, self.very_magic, self.ignore_case)))})
		call s:Log("Post-filter: #files=%s", len(self.files))
	endfu
	fu! cache.refresh(...) closure
		let force = a:0 && a:1
		call s:Log("Refreshing cache force=%s dirty=%s...", force, self.dirty)
		if force || self.dirty
			" FIXME: Decide where to account for magic and case-sensitive.
			if self.dirty >= 3
				" Get the file list
				"let get_files_cmd = printf('rg --files')
				let get_files_cmd = printf('git ls-files --recurse-submodules')
				call s:Log("Reading raw file list: %s", get_files_cmd)
				let self.all_files = get_files_cmd->systemlist()
			endif
			if self.dirty >= 1
				if self.dirty >= 2
					" Make a copy of the unfiltered file list to be filtered in place.
					let self.files = self.all_files[:]
				endif
				call s:Log("Applying filters...")
				call self.apply_filters()
				call s:Log("Writing file list to file: %s", self.file_list_file.path)
				call writefile(
							\ (self.nul_separate_paths
							\ ? [self.files->join("\n")]
							\ : self.files), self.file_list_file.path)
			endif
			let self.dirty = 0
		endif
	endfu
	fu! cache.clear_files(dirty_level) closure
		let self.dirty = a:dirty_level
	endfu
	" TODO: Consider whether this should be combined with previous somehow...
	fu! cache.clear_filters() closure
		let self.dirty = 2
		let self.patts.incl = []
		let self.patts.excl = []
		let self.globs.incl = []
		let self.globs.excl = []
	endfu
	fu! cache.update_dirty(type, add, empty)
		" incl   add   empty   max   description
		" ---------------------------------------------
		" 0      0       0     2     (removing exclude)
		" 0      1       0     1     (adding exclude)
		" 1      0       0     1     (removing include)
		" 1      1       0     2     (adding include)
		" 0      0       1     2     (no more excludes)
		" 0      1       1     1     (adding exclude - N/A)
		" 1      0       1     2     (no more includes)
		" 1      1       1     2     (adding include)
		let max = (a:type == 'incl') == !!a:add || a:empty ? 2 : 1
		let self.dirty = [self.dirty, max]->max()
	endfu
	fu! cache.add_patts(type, ...) closure
		let self.patts[a:type] = self.patts[a:type]->extend(
			\ a:000[:]->filter({idx, patt -> self.patts[a:type]->index(patt) < 0}))
		call self.update_dirty(a:type, 1, 0)
	endfu
	fu! cache.remove_patts(type, bang, ...) closure
		if (!a:0)
			if a:bang
				" Remove all patterns of specified type
				let self.patts[a:type] = []
			else
				echoerr "Must provide at least one pattern if <bang> is not provided."
			endif
		else
			" Remove patterns provided as input.
			let self.patts[a:type] = self.patts[a:type]->filter({
						\ patt -> a:000->index(patt) >= 0 })
		endif
		call self.update_dirty(a:type, 0, self.patts.empty())
	endfu
	fu! cache.add_globs(type, ...) closure
		echomsg "Adding globs: " . string(a:000)
		let self.globs[a:type] = self.globs[a:type]->extend(
			\ a:000[:]->filter({idx, patt -> self.globs[a:type]->index(patt) < 0}))
		call self.update_dirty(a:type, 1, 0)
	endfu
	fu! cache.remove_globs(type, bang, ...) closure
		call self.update_dirty(a:type, 0)
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
						\ patt -> a:000->index(patt) >= 0 })
		endif
		call self.update_dirty(a:type, 0, self.globs.empty())
	endfu
	return cache
endfu

let TEST = 0
if TEST
	let c = s:create_fzf_cache('ls')
	echo "Adding patts for ^C and ^D but excluding [SR] and W"
	call c.add_patts('incl', '^C', '^D')
	call c.add_patts('excl', '[SR]', 'W')
	echo c
	echo "-----refresh()"
	echo c.refresh()
	echo "Adding patt for ^NTUSER"
 	call c.add_patts('incl', '^NTUSER')
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


nmap <leader>e
	\ :call <SID>fcache().refresh() \|
	\ :call fzf#run(fzf#wrap({
	\   'source': <SID>fcache().get_edit_source_cmd(),
	\   'sink': 'e'
	\ }))<cr>

" TODO: Consider completion of submodule names.
com -nargs=* Show echo !empty(<q-args>) ? [<f-args>]
			\ ->filter({idx, val -> val != 'files' && val != 'all_files'})
			\ ->map({idx, val -> s:fcache[val]}) : s:fcache
com -bang RebuildCache 
			\ call s:fcache().destroy() |
			\ let s:fcache = s:create_fzf_cache()
com -bang ClearCache call s:fcache().clear_files("a:bang" == "!" ? 3 : 2)
com ClearFilters call s:fcache().clear_filters()
com -nargs=+ AddInclPatts call s:fcache().add_patts('incl', <f-args>)
com -nargs=+ AddExclPatts call s:fcache.add_patts('excl', <f-args>)
com -bang -nargs=* RemoveInclPatts call s:fcache.remove_patts('incl', <bang>0, <f-args>)
com -bang -nargs=* RemoveExclPatts call s:fcache.remove_patts('excl', <bang>0, <f-args>)
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
fu! s:Any(patts, s, vmagic, icase)
	for patt in a:patts
		if a:s =~ (a:vmagic ? '\v' : '') . (a:icase ? '\c' : '')  . patt
			return 1
		endif
	endfor
	return 0
endfu
fu! s:GlobsToPatts(globs)
	return a:globs[:]->map({i, v -> v->glob2regpat()})
endfu

fu! s:Log(fmt, ...)
	if s:log_level > 0
		echomsg call('printf', [a:fmt] + a:000)
	endif
endfu

