" vim:ts=2:sw=2:noet

let s:log_level = 0

" Default configuration
let s:fzf_config = {
			\ 'file_list_file': '',
			\ 'very_magic': 1,
			\ 'ignore_glob_case': 1,
			\ 'ignore_case': 0,
			\ 'nul_separate_paths': 1,
			\ 'get_files_timeout': 30
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
				\ 'files': [],
				\ 'file_list_file': s:calculate_flf_path(cfg),
				\ 'paths': [],
				\ 'globs': [],
				\ 'very_magic': get(cfg, 'very_magic', s:fzf_config.very_magic),
				\ 'ignore_glob_case': get(cfg, 'ignore_glob_case', s:fzf_config.ignore_glob_case),
				\ 'ignore_case': get(cfg, 'ignore_case', s:fzf_config.ignore_case),
				\ 'nul_separate_paths': get(cfg, 'nul_separate_paths', s:fzf_config.very_magic),
				\ 'get_files_timeout': get(cfg, 'get_files_timeout', s:fzf_config.get_files_timeout),
				\ 'clean' : {}
				\ }

	" Display the cache.
	fu! cache.show_cache(bang) closure
		echo "Cache is" self.files_mode == "clean" ? "clean" : "dirty"
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
		if self.files_mode == "clean"
			return self.clean.get_files_cmd
		endif
		" Note: Do NOT 'shellescape' the args: not only is it unnecessary, it will
		" actually break things because Vim passes the args directly to the
		" invoked executable, not to the shell. We do, however, need to escape
		" spaces and backslashes to ensure that Vim correctly splits the line into
		" arguments.
		let self.clean.get_files_cmd = printf('rg --files %s %s %s',
					\ self.ignore_glob_case ? '--glob-case-insensitive' : '',
					\ self.globs
					\ ->mapnew({i, s -> '-g ' . escape(s, ' \')})->join(),
					\ self.paths
					\ ->mapnew({i, s -> escape(s, ' \')})->join())
		return self.clean.get_files_cmd
	endfu
	fu! cache.is_null_job() closure
		return !self->has_key('files_job')
	endfu
	fu! cache.handle_files_gotten(ch, msg) closure
		let info = job_info(self.files_job)
		if info.status == "fail" || info.status == "dead" && info.exitval
			if info.status == "fail"
				echomsg "get_files job failed to start!"
			else
				echomsg "get_files job exited with error!"
			endif
			let self.files_mode = "dirty"
		else
			let self.files_mode = "clean"
		endif
	endfu
	fu! cache.start_getting_files() closure
		call self.mark_dirty(0)
		" TODO: Save the job somewhere.
		let get_files_cmd = self.get_files_cmd()
		call s:Log("files cmd: %s", get_files_cmd)
		call s:Log("output file: %s", self.file_list_file.path)
    let self.files_job = job_start(get_files_cmd,
					\ {"callback": function(self.handle_files_gotten, [], self),
					\  "out_io": "file",
					\  "out_name": self.file_list_file.path}
					\ )
		let self.files_mode = "running"
	endfu
	fu! cache.await_files_stopped()
	endfu
	" The variadic args allow this method to be invoked as job callback. Note
	" that we ignore the channel and msg args because the method does its own
	" checking.
	" Return the current files_mode for convenience.
	fu! cache.await_files_gotten(...) closure
		let start_time = reltime()
		" Wait for job to stop running or timeout.
		while self.files_job->job_status() == "run"
					\ && reltimefloat(reltime(start_time)) < self.get_files_timeout
		endwhile
		" See what happened.
		let info = self.files_job->job_info()
		if info.status == "dead"
			if info.exitval
				echomsg "Job finished with error:" info.exitval
				" Design Decision: Don't auto-restart; let restart be triggered
				" lazily to avoid a barrage of failed calls.
				let self.files_mode = "dirty"
			else
				let self.files_mode = "clean"
			endif
		else " fail or timeout
			if info.status == "fail"
				echomsg "Job failed to start!"
			else " run = timeout
				echomsg "Job timed out!"
			endif
			let self.files_mode = "error"
		endif
		return self.files_mode
	endfu
	fu! cache.stop_getting_files() closure
		if self.is_null_job()
			let self.files_mode = "dirty"
			return
		endif
		let result = self.files_job->job_stop("term") ||
					\ self.files_job->job_stop("kill")
		if !result
			" Unable to stop job
			let self.files_mode = "error"
		else
			let status = self.files_job->job_status()
			if status == "dead" || status == "fail"
				" Note: Caller meant to kill the job, so ignore error codes and/or
				" failure to start.
				let self.files_mode = "dirty"
			else
				" Job shouldn't be running.
				let self.files_mode = "error"
			endif
		endif
		if self.files_mode == "error"
			echomsg "Unable to stop job!"
		endif
	endfu
	fu! cache.ensure_fresh_files(...) closure
		if self.files_mode == "clean"
			return
		elseif self.files_mode == "dirty" || self.files_mode == "error"
			call self.start_getting_files()
		endif
		call self.await_files_gotten()
	endfu
	fu! cache.mark_dirty(autostart) closure
		let self.files_mode = "dirty"
		" Question: Should we avoid this call if self.files_mode indicates it's
		" unnecessary?
		call self.stop_getting_files()
		if a:autostart
			call self.start_getting_files()
		endif
	endfu
	" FIXME: Should this clear filters? Auto-restart?
	fu! cache.clear() closure
		call self.mark_dirty(1)
	endfu
	" TODO: Consider whether this should be combined with previous somehow...
	fu! cache.clear_filters() closure
		let self.paths = []
		let self.globs = []
		call self.mark_dirty(0)
	endfu
	" TODO: One set of methods should handle paths and globs.
	fu! cache.add_paths(...) closure
		let self.paths = self.paths->extend(
			\ a:000[:]->filter({idx, path -> self.paths->index(path) < 0}))
		call self.mark_dirty(1)
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
		call self.mark_dirty(1)
	endfu
	" Interactive front end for glob/patt removal
	fu! cache.remove_globs_or_paths_ui(is_glob) closure
		let which = a:is_glob ? 'globs' : 'paths'

		" Create list of removable globs.
		call fzf#run(fzf#wrap({
					\ 'source': self[which][:],
					\ 'sinklist': { globs_or_paths ->
					\ call(function(self.remove_globs_or_paths, [a:is_glob, 0], self),
					\ globs_or_paths)}}))
	endfu
	" Leading ^ means prepend.
	" Bang means clear existing
	fu! cache.add_globs_or_paths(is_glob, bang,...) closure
		let which = a:is_glob ? 'globs' : 'paths'
		if a:bang
			let self[which] = []
		endif
		let prepend = a:000->len() && a:000[0] == '^'
		" Append or prepend patterns not already in list.
		let self[which] = self[which]->extend(
			\ a:000[:]->filter({idx, patt -> self[which]->index(patt) < 0}),
			\ prepend ? 0 : self[which]->len())
		call self.mark_dirty(1)
	endfu
	fu! cache.remove_globs_or_paths(is_glob, bang, ...) closure
		let which = a:is_glob ? 'globs' : 'paths'
		if (!a:0)
			if a:bang
				" Remove all globs.
				let self[which] = []
			else
				echoerr "Must provide at least one glob if <bang> is not provided."
				return
			endif
		else
			" Remove globs provided as input.
			let globs = a:000
			let self[which] = self[which]->filter({
						\ i, g_or_p -> globs->index(g_or_p) < 0 })
		endif
		call self.mark_dirty(1)
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
" TODO: Once I add stack capability, this will need to be a cleanup function.
au! VimLeave s:fcache->destroy()

	" Map for quickly finding a file to edit.
nmap <leader>e
	\ :call <SID>fcache().ensure_fresh_files() \|
	\ :call fzf#run(fzf#wrap({
	\   'multi': 1,
	\   'source': <SID>fcache().get_edit_source_cmd(),
	\   'sink': 'e'
	\ }))<cr>

nmap <leader>d
	\ : call <SID>fcache().remove_globs_or_paths_ui(1)<cr>
nmap <leader>D
	\ : call <SID>fcache().remove_globs_or_paths_ui(0)<cr>

" TODO: Consider completion of submodule names.
com -bang -nargs=0 Show call s:fcache().show_cache(<bang>0)
com -bang RebuildCache 
			\ call s:fcache().destroy() |
			\ let s:fcache = s:create_fzf_cache()
com -bang ClearCache call s:fcache().clear()
com ClearFilters call s:fcache().clear_filters()
com -bang -nargs=+ AddPaths call s:fcache().add_globs_or_paths(0, <bang>0, <f-args>)
com -bang -nargs=* RemovePaths call s:fcache.remove_globs_or_paths(0, <bang>0, <f-args>)
com -bang -nargs=+ AddGlobs call s:fcache().add_globs_or_paths(1, <bang>0, <f-args>)
com -nargs=+ RemoveGlobs call s:fcache().remove_globs_or_paths(1, <bang>0, <f-args>)
com LoggingOn let s:log_level = 1
com LoggingOff let s:log_level = 0

command! -nargs=+ Grep
	\ :call <SID>fcache().ensure_fresh_files() |
	\ :call fzf#run(fzf#wrap({
	\   'source': 'xargs -0a ' . s:fcache.file_list_file.path . ' grep -E ' . <q-args>
	\   'sink': 'e'
	\ }))<cr>

" TODO: Make vim output with NULs as line sep.
" fzf --read0
" xargs -0
command! -bang -nargs=* Rg
	\ call s:fcache.ensure_fresh_files()
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

