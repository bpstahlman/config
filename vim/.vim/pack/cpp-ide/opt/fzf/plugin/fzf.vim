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

" Create an fcache of specified type.
fu! s:create_fzf_cache(...)
	" Determine project type.
	" TODO: Consider putting this in its own function and perhaps doing more
	" validation.
	" TODO: Consider using stack_parse_args to permit `-' prefix.
	let prj_type = a:0 && type(a:1) == v:t_string
				\ ? a:1 : ''
	let default = 0
	" Get config object for specified project type.
	if empty(prj_type)
		let cfg = s:fzf_config
		let default = 1
	elseif exists('g:fzf_config_' . prj_type)
		let cfg = get(g:, 'fzf_config_' . prj_type)
	else
		echoerr "Project type doesn't exist:" prj_type
		return
	endif

	" TODO: Put options under opts or something.
	" TODO: Don't need dict for file_list_file.
	" TODO: Starting to wonder whether it would be better not to use a
	" containing object, but just have the methods be functions (which could be
	" called as methods, but wouldn't require the duplicate storage).
	let cache = {
				\ 'files': [],
				\ 'file_list_file': s:calculate_flf_path(cfg),
				\ 'paths': [],
				\ 'globs': [],
				\ 'ignore_glob_case': get(cfg, 'ignore_glob_case', s:fzf_config.ignore_glob_case),
				\ 'ignore_case': get(cfg, 'ignore_case', s:fzf_config.ignore_case),
				\ 'get_files_timeout': get(cfg, 'get_files_timeout', s:fzf_config.get_files_timeout),
				\ 'files_mode': "dirty",
				\ 'clean' : {}
				\ }

	" Display the cache.
	fu! cache.show_cache(...) closure
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
	fu! cache.show_methods() closure
		for [key, FnOrVal] in items(self)
			if type(FnOrVal) == 2
				echo printf("%s: %s", key, function(FnOrVal))
			endif
		endfor
	endfu
	" Return search command for the indicated search program, which must be one
	" of 'grep', 'rg'
	fu! cache.get_search_cmd(program,...) closure
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
	fu! cache.get_edit_source_cmd() closure
		return 'cat ' . self.file_list_file.path
	endfu
	" Call this whenever an fcache is made current.
	fu! cache.activate(autostart) closure
		let dir_ok = self.check_directory()
		if self.files_mode != "clean"
			" Design Decision: Don't autostart if we're not in the right directory.
			call self.mark_dirty(dir_ok && a:autostart)
		endif
	endfu
	fu! cache.destroy() closure
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
	if has_key(cfg, 'get_files_cmd')
		" Use user-defined function.
		let cache.get_files_cmd = function(cfg.get_files_cmd, [], cache)
	else
		fu! cache.get_files_cmd() closure
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
	endif
	fu! cache.search_files(program, bang, ...)
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
	fu! cache.is_null_job() closure
		return !self->has_key('files_job')
	endfu
	fu! cache.handle_files_gotten(...) closure
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
	fu! cache.start_getting_files() closure
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
	fu! cache.await_files_gotten(...) closure
		let start_time = reltime()
		" Wait for job to stop running or timeout.
		while self.files_job->job_status() == "run"
					\ && reltimefloat(reltime(start_time)) < self.get_files_timeout
		endwhile
		" Update status
		call self.handle_files_gotten()
	endfu
	fu! cache.stop_getting_files() closure
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
	fu! cache.check_directory() closure
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
	fu! cache.ensure_fresh_files(...) closure
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
	fu! cache.mark_dirty(autostart) closure
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
	if !default
		" Start gathering files for non-default configuration.
		call cache.mark_dirty(1)
	endif
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

fu! s:stack_parse_args(args)
	let ret = ['', '']
	if a:args->empty()
		" Default everything
		return ret
	endif
	" We have at least one arg.
	if a:args[0][0] == "-"
		" Strip the hyphen
		let ret[0] = a:args[0][1:]
	endif
	if a:args->len() == 1
		" No SAVE_NAME provided
		return ret
	endif
	" Join the potentially split SAVE_NAME into a single string.
	let ret[1] = a:args[1:]->join(' ')
	return ret
endfu

" Stack functionality

fu! s:find_fcache_by_name(name)
	if empty(a:name)
		return -1
	endif
	return s:fcache_stack->mapnew({i, v -> get(v, '$save_name', '')})
				\ ->index(a:name)
endfu
fu! s:stack_clear()
	for fcache in s:fcache_stack
		call fcache.destroy()
	endfor
	let s:fcache_stack = []
endfu
fu! s:stack_show()
	let stack_idx = 0
	for fc in reverse(s:fcache_stack[:])
		echomsg "-- Element" stack_idx "--" get(fc, '$save_name', '')
		call fc.show_cache()
		let stack_idx += 1
	endfor
endfu
fu! s:stack_push(...)
	let [tmpl_name, save_name] = s:stack_parse_args(a:000)
	let fcache = s:fcache()
	if !empty(save_name)
		" A save name has been specified.
		let fcache['$save_name'] = save_name
		" Make sure the name doesn't already exist.
		let idx = s:find_fcache_by_name(save_name)
		if idx >= 0
			" Something already saved under that name!
			let ans = input("Fcache named '" . save_name . "' already exists: replace? y/[n]", "n")
			if ans !~? '^y'
				return " cancel push
			endif
			let rem = remove(s:fcache_stack, idx)
			call rem.destroy()
		endif
	endif
	call s:Log("Pushing save_name='%s'", save_name)
	call add(s:fcache_stack, fcache)
	" Switch to a new fcache
	call s:Log("Switching to cache with template='%s'", tmpl_name)
	let s:fcache = s:create_fzf_cache(tmpl_name)
endfu
fu! s:stack_pop(...)
	if s:fcache_stack->empty()
		echoerr "Can't pop empty stack"
		return
	endif
	" Get name if provided.
	let save_name = a:0 ? a:1 : ''
	if !empty(save_name)
		" Convert save_name to index
		let idx = s:find_fcache_by_name(save_name)
		if idx < 0
			echoerr "No such named fcache:" save_name
			return
		endif
	else
		let idx = -1 " pop the most recent fcache
	endif
	" Pop the specified fcache and activate it.
	let s:fcache = remove(s:fcache_stack, idx)
	call s:fcache.activate(1)
endfu
fu! s:switch_to(tmpl_name)
	" Tear down the fcache we're replacing.
	call s:fcache.destroy()
	let [name, _] = s:stack_parse_args([a:tmpl_name])
	" Create new fcache.
	let s:fcache = s:create_fzf_cache(name)
endfu
" TODO: Need a command for switching to new proct type without push
" TODO: I'm thinking there may be no point to apply. Even more so if we always
" keep current fcache on stack. Hmm... Not sure about that...
fu! s:stack_apply(...)
endfu
" TODO: Consider making this global for save to viminfo
let s:fcache_stack = []
com -nargs=0 ShowStack :call s:stack_show()
com -nargs=0 Clear :call s:stack_clear()
com -nargs=* Push :call s:stack_push(<f-args>)
" TODO: Difference between <q-args> and <f-args>
com -nargs=? Pop :call s:stack_pop(<f-args>)
com -nargs=? Apply :call s:stack_apply(<f-args>)
com -nargs=? Switch :call s:switch_to(<f-args>)


let TEST = 1
if TEST
	LoggingOn
	" Vim-visual-multi
	cd ~/.vim/plugged/vim-visual-multi/
	Switch vim
	sleep 5
	" TODO: Would probably be nice to be able to specify a new directory with
	" Push command.
	" Stellar D
	cd /mnt/d/sc/gitAll
	Push -stellar vim-visual
	AddGlobs gpc/** ida/**
	AddGlobs !gpc/base/ !ida/common
	sleep 10
	" Vim src
	cd ~/src/vim/src/
	Push -c d-sc
	
endif


