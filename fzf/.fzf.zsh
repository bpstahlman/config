# Setup fzf
# ---------
if [[ ! "$PATH" == */home/bstahlman/.fzf/bin* ]]; then
  export PATH="${PATH:+${PATH}:}/home/bstahlman/.fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/home/bstahlman/.fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/home/bstahlman/.fzf/shell/key-bindings.zsh"
