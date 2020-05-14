# Configure a color prompt containing username/host/cwd.
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# This should be the default.
shopt -s histappend
#[[ -r ~/cac-enabled-git-env.sh ]] && . ~/cac-enabled-git-env.sh

# Prepend rakudobrew to PATH.
export PATH=~/.rakudobrew/bin:$PATH

# Prepend Rust's cargo bin dir to PATH (for packages installed with `cargo
# install')
PATH+=~/.local/bin:~/bin
PATH+=~/.perl6/bin:/opt/rakudo-pkg/bin:/opt/rakudo-pkg/share/perl6/site/bin
# Put latest racket in front of the ancient one installed by ubuntu package
# manager.
# TODO: Probably just remove Ubuntu's.
PATH+=~/racket/bin
PATH+=~/anarki
PATH+=~/bin
PATH+=~/.cargo/bin
export PATH

export STACK_INSTALL_PATH=~/.local/bin

# Note: Provide an fzf overload of readline's reverse incremental history
# search on C-R (which readline's vi defaults map to readline's
# reverse-search-history).
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
