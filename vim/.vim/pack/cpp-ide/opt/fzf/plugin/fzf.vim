" vim:ts=2:sw=2:noet

" Default configuration
let s:fzf_config = {
			\ 'get_files_cmd': 'git ls-files --recurse-submodules',
			\ 'file_list_file': '',
			\ 'very_magic': 1,
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

fu! Dummy(...)
	echomsg a:000
endfu

fu! s:create_fzf_cache(...)
	let cfg = get(g:, 'fzf_config', {})

	" TODO: Put options under opts or something.
	" TODO: Don't need dict for file_list_file.
	let cache = {
				\ 'dirty': 2,
				\ 'files': [],
				\ 'get_files_cmd': get(cfg, 'get_files_cmd', s:fzf_config.get_files_cmd),
				\ 'file_list_file': s:calculate_flf_path(cfg),
				\ 'patts': {'incl': [], 'excl': []},
				\ 'globs': {'incl': [], 'excl': []},
				\ 'very_magic': get(cfg, 'very_magic', s:fzf_config.very_magic),
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
		return 'cat ' . cache.file_list_file.path
					\ . (cache.nul_separate_paths ? ' | tr \\0 \\n' : '')
	endfu
	fu! cache.get_globs() closure
		return
					\ cache.globs.incl->mapnew('"-g ''" . v:val . "''"')->join()
					\ . cache.globs.excl->mapnew('"-g ''!" . v:val . "''"')->join()
	endfu
	fu! cache.refresh(...) closure
		let force = a:0 && a:1
		if force || cache.dirty
			fu! Any(patts, s, vmagic)
				for patt in a:patts
					if a:s =~ (a:vmagic ? '\v' : '') . patt
						return 1
					endif
				endfor
				return 0
			endfu

			if cache.dirty >= 2
				" Get the file list
				"let cache.files = cache.get_files_cmd->systemlist()
				let get_files_cmd = printf('rg --files %s', cache.get_globs())
				echomsg "Getting files: " . get_files_cmd
				let cache.files = get_files_cmd->systemlist()
			endif
			if cache.dirty >= 1
				" Apply (or reapply) the filter
				let cache.files = cache.files->filter({
							\ idx, path ->
							\ (cache.patts.incl->empty()
							\  || cache.patts.incl->Any(path, cache.very_magic))
							\ && (cache.patts.excl->empty()
							\     || !cache.patts.excl->Any(path, cache.very_magic))})
				let cache.files = cache.files->filter({
							\ idx, path ->
							\ (cache.patts.incl->empty()
							\  || cache.patts.incl->Any(path, cache.very_magic))
							\ && (cache.patts.excl->empty()
							\     || !cache.patts.excl->Any(path, cache.very_magic))})

				call writefile(
							\ (cache.nul_separate_paths
							\ ? [cache.files->join("\n")]
							\ : cache.files), cache.file_list_file.path)
			endif
			let cache.dirty = 0
		endif
	endfu
	fu! cache.clear_files() closure
		let cache.dirty = 2
	endfu
	fu! cache.add_patts(type, ...) closure
		let cache.dirty = [cache.dirty, 1]->max()
		let cache.patts[a:type] = cache.patts[a:type]->extend(
			\ a:000[:]->filter({idx, patt -> cache.patts[a:type]->index(patt) < 0}))
	endfu
	fu! cache.remove_patts(type, bang, ...) closure
		let cache.dirty = [cache.dirty, 1]->max()
		if (!a:0)
			if a:bang
				" Remove all patterns of specified type
				let cache.patts[a:type] = []
			else
				echoerr "Must provide at least one pattern if <bang> is not provided."
			endif
		else
			" Remove patterns provided as input.
			let cache.patts[a:type] = cache.patts[a:type]->filter({
						\ patt -> a:000->index(patt) >= 0 })
		endif
	endfu
	fu! cache.add_globs(type, ...) closure
		let cache.dirty = [cache.dirty, 1]->max()
		let cache.globs[a:type] = cache.globs[a:type]->extend(
			\ a:000[:]->filter({idx, patt -> cache.globs[a:type]->index(patt) < 0}))
	endfu
	fu! cache.remove_globs(type, bang, ...) closure
		let cache.dirty = [cache.dirty, 1]->max()
		if (!a:0)
			if a:bang
				" Remove all patterns of specified type
				let cache.globs[a:type] = []
			else
				echoerr "Must provide at least one glob if <bang> is not provided."
			endif
		else
			" Remove patterns provided as input.
			let cache.globs[a:type] = cache.globs[a:type]->filter({
						\ patt -> a:000->index(patt) >= 0 })
		endif
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

nmap <leader>e
	\ :call <SID>fcache().refresh() \|
	\ :call fzf#run(fzf#wrap({
	\   'source': <SID>fcache().get_edit_source_cmd(),
	\   'sink': 'e'
	\ }))<cr>

" TODO: Consider completion of submodule names.
com -nargs=* Show echo !empty(<q-args>) ? [<f-args>]->map({idx, val -> s:fcache[val]}) : s:fcache
com -nargs=? Clear call s:fcache().clear_files()
com -nargs=+ AddInclPatts call s:fcache().add_patts('incl', <f-args>)
com -nargs=+ AddExclPatts call s:fcache.add_patts('excl', <f-args>)
com -bang -nargs=* RemoveInclPatts call s:fcache.remove_patts('incl', <bang>0, <f-args>)
com -bang -nargs=* RemoveExclPatts call s:fcache.remove_patts('excl', <bang>0, <f-args>)
com -nargs=+ AddInclGlobs call s:fcache().add_globs('incl', <f-args>)
com -nargs=+ AddExclGlobs call s:fcache.add_globs('excl', <f-args>)
com -bang -nargs=* RemoveInclGlobs call s:fcache.remove_globs('incl', <bang>0, <f-args>)
com -bang -nargs=* RemoveExclGlobs call s:fcache.remove_globs('excl', <bang>0, <f-args>)

com -nargs=+ Grep
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
