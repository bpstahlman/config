" vim:ts=2:sw=2:noet

let s:log_level = 0

" Default configuration
" TODO: Reconsider file_list_file approach. Purely temporary or persistent?
" Maybe have a common directory? Support lots of ways or just one?
let s:fzf_config = {
			\ 'file_list_file': '',
			\ 'ignore_glob_case': 1,
			\ 'ignore_case': 0,
			\ 'get_files_timeout': 30
\ }

fu! s:calculate_flf_path() dict
	let flf_path = self->get('file_list_file', '')
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

" Display the cache.
fu! s:show(...) dict
	let bang = a:0 && !!a:1
	echo "cache status:" self.files_mode == "clean" ? "clean" : "dirty"
	if self.files_mode == "clean"
		echo "saved (\"clean\") properties:" string(self.clean)
	endif
	echo "get_files_cmd:" self.get_files_cmd()
	echo "file list:" self.file_list_file
	echo "file listing command:" string(self.get_files_cmd())
	echo "paths:" self.paths
	echo "globs:" self.globs
	echo printf("options: ignore_glob_case=%s ignore_patt_case=%s",
				\ self.ignore_glob_case ? "on" : "off",
				\ self.ignore_case ? "on" : "off")
	if (bang)
		call self.show_methods()
	endif
endfu
" Note: Wish I'd known about `:function {N}' long ago...
fu! s:show_methods() dict
	for [key, FnOrVal] in items(self)
		if type(FnOrVal) == 2
			echo printf("%s: %s", key, function(FnOrVal))
		endif
	endfor
endfu
" Return search command for the indicated search program, which must be one
" of 'grep', 'rg'
fu! s:get_search_cmd(program,...) dict
	" TODO: Make --smart-case a script option?
	let leading_opts =
				\ (self.ignore_case ? '--ignore-case' : '')
				\ . (a:program == 'rg'
				\ ? '--column --line-number --no-heading --color=always --smart-case'
				\ : '--line-number --with-filename --extended-regexp --color')
	let ret = printf('xargs -a %s %s %s %s'
	\   , s:fcache.file_list_file.path
	\   , a:program
	\   , leading_opts
	\   , a:000->mapnew({i, p -> shellescape(p)})->join())
	call s:Log("Search command: %s", ret)
	return ret
endfu
" Return command 
fu! s:get_edit_source_cmd() dict
	return 'cat ' . self.file_list_file.path
endfu
" Call this whenever an fcache is made current.
fu! s:activate(autostart) dict
	let dir_ok = self.check_directory()
	if self.files_mode != "clean"
		" Design Decision: Don't autostart if we're not in the right directory.
		call self.mark_dirty(dir_ok && a:autostart)
	endif
endfu
fu! s:destroy() dict
	echomsg "Bye!"
	call self.mark_dirty(0)
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
fu! s:get_files_cmd() dict
	if self.files_mode == "clean"
		return self.clean.get_files_cmd
	endif
	" Note: Do NOT 'shellescape' the args: not only is it unnecessary, it will
	" actually break things because Vim passes the args directly to the
	" invoked executable, not to the shell. We do, however, need to escape
	" spaces and backslashes within globs/paths to ensure that Vim correctly
	" splits the line into arguments.
	" Alternate Approach: Return an array of desired command line args.
	let self.clean.get_files_cmd = printf('rg --files %s %s %s',
				\ self.ignore_glob_case ? '--glob-case-insensitive' : '',
				\ self.globs
				\ ->mapnew({i, s -> '-g ' . escape(s, ' \')})->join(),
				\ self.paths
				\ ->mapnew({i, s -> escape(s, ' \')})->join())
	return self.clean.get_files_cmd
endfu
fu! s:search_files(program, bang, ...)
	call s:fcache().ensure_fresh_files()
	let cmd = self.get_search_cmd->call([a:program] + a:000, self)
	if 1
		call fzf#vim#grep(cmd, 1, fzf#vim#with_preview(), a:bang)
	else
		" FIXME! Remove this arm...
		call s:Log("File search command: %s", cmd)
		let wrapopts = fzf#wrap({
					\ 'source': cmd,
					\ 'options': ['--ansi']})
		if a:bang
			"let wrapopts.options .= " " . fzf#vim#with_preview().options
						"\ ->mapnew({i, v -> shellescape(v)})->join(" ")
			let wrapopts = fzf#vim#with_preview(wrapopts)
		endif
		call s:Log("Calling fzf#run: %s", string(wrapopts))
		call fzf#run(wrapopts)
	endif
endfu
fu! s:is_null_job() dict
	return !self->has_key('files_job')
endfu
fu! s:handle_files_gotten(...) dict
	let info = self.files_job->job_info()
	if info.status == "dead"
		if info.exitval
			echomsg "Job finished with error:" info.exitval
			" Design Decision: Don't auto-restart; let restart be triggered
			" lazily to avoid a barrage of failed calls.
			let self.files_mode = "dirty"
		else
			let self.files_mode = "clean"
			let self.clean.dir = getcwd()
		endif
	else " fail or timeout
		if info.status == "fail"
			echomsg "Job failed to start!"
		else " run = timeout
			echomsg "Job timed out!"
		endif
		let self.files_mode = "error"
	endif
endfu
fu! s:start_getting_files() dict
	call self.mark_dirty(0)
	" TODO: Save the job somewhere.
	let get_files_cmd = self.get_files_cmd()
	call s:Log("files cmd: %s", get_files_cmd)
	call s:Log("output file: %s", self.file_list_file.path)
	let self.files_job = job_start(get_files_cmd,
				\ {"exit_cb": function(self.handle_files_gotten, [], self),
				\  "out_io": "file",
				\  "out_name": self.file_list_file.path}
				\ )
	let self.files_mode = "running"
endfu
" The variadic args allow this method to be invoked as job callback. Note
" that we ignore the channel and msg args because the method does its own
" checking.
" Return the current files_mode for convenience.
fu! s:await_files_gotten(...) dict
	let start_time = reltime()
	" Wait for job to stop running or timeout.
	while self.files_job->job_status() == "run"
				\ && reltimefloat(reltime(start_time)) < self.get_files_timeout
	endwhile
	" Update status
	call self.handle_files_gotten()
endfu
fu! s:stop_getting_files() dict
	if self.is_null_job() | return | endif
	" Send increasingly forcible stop signals in timed loop, awaiting a
	" process status other than "run".
	" Caveat: Any given SIGTERM may have no effect: Vim returning true simply
	" means the signal is supported on the OS. Keep sending the current signal
	" in loop till process is dead or we time out.
	" Note: Simply waiting is pointless if we don't send additional signals.
	for sig in ['term', 'kill']
		let ts = reltime()
		while reltimefloat(reltime(ts)) < 1 && self.files_job->job_status() == "run"
			let result = self.files_job->job_stop(sig)
		endwhile
	endfor
	" Did we simply time out, or has process terminated?
	let status = self.files_job->job_status()
	if status == "dead" || status == "fail"
		" Note: Caller meant to kill the job, so ignore error codes and/or
		" failure to start.
		let self.files_mode = "dirty"
	else
		" Job shouldn't still be running!
		let self.files_mode = "error"
		echomsg "Unable to stop job!"
	endif
endfu
" Offer to change to correct directory if we know we're in the wrong one.
" Return 0 iff we know we're in the wrong dir when we leave the function.
fu! s:check_directory() dict
	if self.files_mode == "clean" && self.clean.dir != getcwd()
		" Cache should be clean, but directory change has rendered relative
		" pathnames meaningless.
		" TODO: Rework this prompt...
		let ans = input(
					\ "Current directory does not correspond to fcache. Change to "
					\ . self.clean.dir . "? ([y]/n)", 'y')
		if ans =~? 'y'
			" Should be clean after directory change.
			exe 'cd' self.clean.dir
		else
			return 0
		endif
	endif
	return 1
endfu
fu! s:ensure_fresh_files(...) dict
	if self.files_mode == "clean"
		" Make sure we're in correct directory.
		if !self.check_directory()
			echomsg "Warning: Mismatch between current and cached directory may result"
						\ "in failure to find files."
		endif
		return
	elseif self.files_mode == "dirty" || self.files_mode == "error"
		call self.start_getting_files()
	endif
	call self.await_files_gotten()
endfu
fu! s:mark_dirty(autostart) dict
	let self.files_mode = "dirty"
	let self.clean = {}
	" Question: Should we avoid this call if self.files_mode indicates it's
	" unnecessary?
	call self.stop_getting_files()
	if a:autostart
		call self.start_getting_files()
	endif
endfu
" FIXME: Should this clear filters? Auto-restart?
fu! s:clear() dict
	call self.mark_dirty(1)
endfu
" TODO: Consider whether this should be combined with previous somehow...
fu! s:clear_filters() dict
	let self.paths = []
	let self.globs = []
	call self.mark_dirty(0)
endfu
" TODO: One set of methods should handle paths and globs.
fu! s:add_paths(...) dict
	let self.paths = self.paths->extend(
		\ a:000[:]->filter({idx, path -> self.paths->index(path) < 0}))
	call self.mark_dirty(1)
endfu
fu! s:remove_paths(bang, ...) dict
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
fu! s:remove_globs_or_paths_ui(is_glob) dict
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
fu! s:add_globs_or_paths(is_glob, bang,...) dict
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
fu! s:remove_globs_or_paths(is_glob, bang, ...) dict
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

fu! s:create_fcache(...)
	" Determine project type.
	" TODO: Consider putting this in its own function and perhaps doing more
	" validation.
	" TODO: Consider using stack_parse_args to permit `-' prefix.
	let tmpl = a:0 && type(a:1) == v:t_string ? a:1 : ''
	let default = 0
	" Get config object for specified project type.
	if empty(tmpl)
		let cfg = s:fzf_config
		let default = 1
	elseif exists('g:fzf_config_' . tmpl)
		" Use user-defined config.
		let cfg = get(g:, 'fzf_config_' . tmpl)
	else
		echoerr "Project type doesn't exist:" tmpl
		return
	endif
	" TODO: Put options under opts or something.
	" TODO: Don't need dict for file_list_file.
	if has_key(cfg, 'get_files_cmd')
		" Use user-defined function.
		let cache.get_files_cmd = function(cfg.get_files_cmd, [], cache)
	endif
	let cache = {
				\ 'files': [],
				\ 'file_list_file': call('s:calculate_flf_path', [], cfg),
				\ 'paths': [],
				\ 'globs': [],
				\ 'ignore_glob_case': get(cfg, 'ignore_glob_case', s:fzf_config.ignore_glob_case),
				\ 'ignore_case': get(cfg, 'ignore_case', s:fzf_config.ignore_case),
				\ 'get_files_timeout': get(cfg, 'get_files_timeout', s:fzf_config.get_files_timeout),
				\ 'files_mode': "dirty",
				\ 'clean' : {},
	\ }
	" Add methods
	let cache = cache->extend({
				\ 'show': function('s:show'),
				\ 'show_methods': function('s:show_methods'),
				\ 'get_search_cmd': function('s:get_search_cmd'),
				\ 'get_edit_source_cmd': function('s:get_edit_source_cmd'),
				\ 'activate': function('s:activate'),
				\ 'destroy': function('s:destroy'),
				\ 'get_files_cmd':
				\   cfg->has_key('get_files_cmd') && cfg.get_files_cmd->type() == function('v:t_fun')
				\   ?	cfg.get_files_cmd : function('s:get_files_cmd'),
				\ 'search_files': function('s:search_files'),
				\ 'is_null_job': function('s:is_null_job'),
				\ 'handle_files_gotten': function('s:handle_files_gotten'),
				\ 'start_getting_files': function('s:start_getting_files'),
				\ 'await_files_gotten': function('s:await_files_gotten'),
				\ 'stop_getting_files': function('s:stop_getting_files'),
				\ 'check_directory': function('s:check_directory'),
				\ 'ensure_fresh_files': function('s:ensure_fresh_files'),
				\ 'mark_dirty': function('s:mark_dirty'),
				\ 'clear': function('s:clear'),
				\ 'clear_filters': function('s:clear_filters'),
				\ 'add_paths': function('s:add_paths'),
				\ 'remove_paths': function('s:remove_paths'),
				\ 'remove_globs_or_paths_ui': function('s:remove_globs_or_paths_ui'),
				\ 'add_globs_or_paths': function('s:add_globs_or_paths'),
				\ 'remove_globs_or_paths': function('s:remove_globs_or_paths'),
				\ }, "error")
	" Return the object.
	if !default
		" Start gathering files for non-default configuration.
		call cache.mark_dirty(1)
	endif
	return cache
endfu

" Create the default project file cache.
" TODO: Find a way to defer...
let s:fcache = s:create_fcache()
fu! s:fcache()
	return s:fcache
endfu
" Make sure the fcache is cleaned up at shutdown.
au! VimLeave s:fcache->destroy()

" Map for quickly finding a file to edit.
" TODO: Consider whether to allow interactive specification (e.g., using fzf)
" of a file subset for subsequent searches.
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
com -bang -nargs=0 Show call s:fcache().show(<bang>0)
com -nargs=? Build
			\ call s:fcache().destroy() |
			\ let s:fcache = s:create_fcache(<f-args>)
com -bang Clear call s:fcache().clear()
com ClearFilters call s:fcache().clear_filters()
com -bang -nargs=+ AddPaths call s:fcache().add_globs_or_paths(0, <bang>0, <f-args>)
com -bang -nargs=* RemovePaths call s:fcache.remove_globs_or_paths(0, <bang>0, <f-args>)
com -bang -nargs=+ AddGlobs call s:fcache().add_globs_or_paths(1, <bang>0, <f-args>)
com -nargs=+ RemoveGlobs call s:fcache().remove_globs_or_paths(1, <bang>0, <f-args>)
com LoggingOn let s:log_level = 1
com LoggingOff let s:log_level = 0

" Grep commands
command! -bang -nargs=* Rg
	\ call s:fcache.search_files('rg', <bang>0, <f-args>)
command! -bang -nargs=* Grep
	\ call s:fcache.search_files('grep', <bang>0, <f-args>)

" Ancillary functions
fu! s:Log(fmt, ...)
	if s:log_level > 0
		echomsg call('printf', [a:fmt] + a:000)
	endif
endfu

let TEST = 1
if TEST
	LoggingOn
	" Stellar D
	cd /mnt/d/sc/gitAll
	Build stellar
	AddGlobs gpc/** ida/**
	AddGlobs !gpc/base/ !ida/common
	
endif


