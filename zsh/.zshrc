# Lines configured by zsh-newuser-install
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory hist_ignore_dups hist_subst_pattern prompt_subst
# Double `'' to embed single quote in single-quoted strings
setopt rc_quotes
# Note: Different from Bash's extended glob.
setopt extended_glob
# Support bash-like extended glob constructs.
setopt ksh_glob

# Vi line-editing
bindkey -v

# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/cygdrive/c/Users/stahlmanb/.zshrc'

autoload -Uz compinit
compinit

autoload -U promptinit
promptinit

# End of lines added by compinstall

# Allow use of `#' in normal mode to comment a line.
# Note: Zsh's edit buffer stack may eventually obviate need for this...
setopt interactivecomments

# zed editor is *extremely* useful for editing both files and functions (-F)
autoload -U zed

# Load version control utilities.
autoload -Uz vcs_info
# Disable all but git and svn for reasons of efficiency.
zstyle ':vcs_info:*' disable bzr cdv darcs fossil hg mtn p4 svk tla

# Set up Git-specific prompt goodies...
zstyle ':vcs_info:*' actionformats \
 '%F{5}(%f%s%F{5})%F{3}-%F{5}[%F{2}%b%F{3}|%F{1}%a%F{5}]%f '
# If get-revision isn't set, git commit numbers won't be available.
zstyle ':vcs_info:*' get-revision yes
zstyle ':vcs_info:*' formats       \
 '%F{5}(%f%s%F{5})%F{3}-%F{5}[%F{2}%b%F{5}]%F{3}-%F{5}(%f%6.6i%F{5})'
zstyle ':vcs_info:(sv[nk]|bzr):*' branchformat '%b%F{1}:%F{3}%r'
# vcs_info must be called in pre-cmd hook to populate ${vcs_info_msg_0_}
precmd () { vcs_info }
# Note: prompt_subst must be set for this to work.
PS1='%F{5}[%F{2}%n%F{5}] %F{3}%3~ ${vcs_info_msg_0_}%f%# '

# Source stuff that needs to be available for any script (even non-interactive).
# TODO: Consider whether I should use .zshenv for this instead.
# Rationale: .zprofile is sourced only for login shells.
[[ -a ~/.zprofile ]] && . ~/.zprofile

# TODO: Figure out strategy for determining when it's appropriate to switch to ~

# zle widget bindings

USE_META_FOR_SEARCH_MAPS=1
if (( ! ${+USE_META_FOR_SEARCH_MAPS} )); then
	# Remap flow-control stop to C-^ (requires Shift) to free up C-s for more commonly used widgets.
	# Note: flow-control start retains default binding: C-q.
	stty stop '^^'
	bindkey -M viins '^r' history-beginning-search-backward
	bindkey -M viins '^s' history-beginning-search-forward

	bindkey -M vicmd '^r' history-incremental-search-backward
	bindkey -M vicmd '^s' history-incremental-search-forward
else
	bindkey -M viins '\er' history-beginning-search-backward
	bindkey -M viins '\es' history-beginning-search-forward

	bindkey -M vicmd '\er' history-incremental-search-backward
	bindkey -M vicmd '\es' history-incremental-search-forward

	# Note: Could alternatively use vi-repeat-search and vi-rev-repeat-search
	bindkey -M isearch '\er' history-incremental-search-backward
	bindkey -M isearch '\es' history-incremental-search-forward
fi

bindkey -M vicmd '#' vi-pound-insert
bindkey -M viins '\eg' get-line
bindkey -M viins '\ep' push-line-or-edit
# Note: When history scrolling has populated the editing buffer, we'll often be in cmd mode when this functionality is
# needed. (Ideally, would also end up in cmd mode, but that's not how it works).
bindkey -M viins '^O' accept-line-and-down-history
bindkey -M vicmd '^O' accept-line-and-down-history

# Question: Is this needed? ^L is default clear-screen. This one's just for redisplaying buffer in incremental search.
bindkey -M vicmd '^xr' redisplay

# vim:tw=120

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
