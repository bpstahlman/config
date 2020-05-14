# Setup some default paths. Note that this order will allow user installed
# software to override 'system' software.
# Note: This was copied from Bash profile, but should work under zsh as well.
: ${ORIGINAL_PATH=${PATH}}

# Ensure no duplicate entries in tied path var.
typeset -U path
if [ ${CYGWIN_NOWINPATH-addwinpath} = "addwinpath" ] ; then
	path=(/usr/local/bin /usr/bin $path)
else
	PATH="/usr/local/bin:/usr/bin"
fi

# I like a place to put some custom tools.
# Note: Intentionally putting it before /usr/bin and /usr/local/bin so it can override.
path=(~/bin $path)

# TODO: Use k parameter subscript flag to implement a sort of case for uname -a
# values (to avoid running certain things when not running Cygwin).
# Source any local (machine-specific) startup scripts.
profdir=~/.local-profile.d
if [[ -d $profdir ]]; then
	for f in $profdir/*; do
		[[ -a $f ]] && . $f
	done
fi


