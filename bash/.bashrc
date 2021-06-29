if [[ $- == *i* ]]; then
	# Caveat: These commands may fail if we're not running in a tty.
	# Note that bashrc isn't really intended for non-interactive use anyways.

	# Obviate need for .inputrc
	set -o vi

	# Create an informative, multi-line prompt.
	# TODO: Add some colors...
	PS1='\e[1;92m|\e[0m \e[0;96m(\!)\e[0m - \e[0;34m\t\e[0m - \e[0;32m\u@\h\e[0m:  \e[0;34m\w\e[0m\n\$ '

	# Reclaim \cS for readline usage.
	# Rationale: The readline usage is much more common than the flow-control
	# usage, and \cS is prime keyboard real-estate.
	# Note: CTRL-^ is the same as CTRL-6, so shift key isn't necessary.
	stty stop ^^
fi

# Make sure my personal bin comes first.
# TODO: Consider moving these PATH settings to ~/.bash_profile
# TODO: Probably remove ~/bin in favor of ~/.local/bin
PATH=~/bin:~/.local/bin:$PATH

# Load pyenv.
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# Prevent last terminal closed from overwriting history of terminals closed earlier...
shopt -s histappend
# Re-edit a failed history expansion.
shopt -s histreedit
# Verify results of history expansion before execution.
# Note: Someday, may want to disable this...
shopt -s histverify
# Save multi-line commands with embedded newlines.
shopt -s lithist
# Enable extended globbing
shopt -s extglob

# Remove older occurrences of same command.
HISTCONTROL=erasedups
HISTTIMEFORMAT='%F %T: '
HISTSIZE=5000
# Note: Make HISTFILESIZE significantly larger than what we can hold within a
# session.
# Rationale: Facilitate recovery without slowing down normal usage.
HISTFILESIZE=50000

# TODO: Find out what this is...
export STACK_INSTALL_PATH=~/.local/bin

# Source local bashrc(s) (if they exist)
if [ -f /etc/bashrc.local ]; then
    . /etc/bashrc.local
fi
if [ -f ~/.bashrc.local ]; then
    . ~/.bashrc.local
fi

# Enable fzf goodies in bash shell.
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

#source /home/bstahlman/.config/broot/launcher/bash/br
