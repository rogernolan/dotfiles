if type -q fish_add_path
    fish_add_path --move --path "$HOME/.local/bin" "$HOME/bin" "$HOME/go/bin"
else
    set -gx PATH "$HOME/.local/bin" "$HOME/bin" "$HOME/go/bin" $PATH
end

set -gx EDITOR (string split ' ' -- "vim" | string join '')
set -gx VISUAL $EDITOR

alias ll 'ls -lah'
alias la 'ls -A'
alias gs 'git status'
alias gd 'git diff'

if type -q direnv
    direnv hook fish | source
end

if test -r "$HOME/.config/rog/private.fish"
    source "$HOME/.config/rog/private.fish"
end
