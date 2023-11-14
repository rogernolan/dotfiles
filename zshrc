
export PATH=$PATH:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:~/binexport:/usr/local/opt/python/libexec/bin

ZSH=$HOME/.oh-my-zsh

# Clean is a reasonable compromise between information and readbility.
ZSH_THEME="clean"

# aliases for frequent commnds
alias zshconfig="choc ~/.zshrc"
alias ohmyzsh="choc ~/.oh-my-zsh"
alias wo="workon"
alias py="python"

CASE_SENSITIVE="true"

# how often before auto-updates occur in days
export UPDATE_ZSH_DAYS=5

COMPLETION_WAITING_DOTS="true"

# Uncomment following line if you want to disable marking untracked files under
# VCS as dirty. This makes repository status check for large repositories much,
# much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

source $ZSH/oh-my-zsh.sh
plugins=(git git-extras git-flow python brew docker npm osx pod  terminalapp virtualenvwrapper)

# Put any proprietary or private functions/values in ~/.private, and this will source them
if [ -f $HOME/.private ]; then
    source $HOME/.private
fi

if [ -f $HOME/.profile ]; then
    source $HOME/.profile  # Read Mac .profile, if present.
fi

# Shell Aliases
## Git Aliases
alias gs='git status '
alias ga='git add '
alias gaa='git add --all'
alias gb='git branch '
alias gc='git commit'
alias gd='git diff'
alias gou='git checkout '
alias gk='gitk --all&'
alias gx='gitx --all'
alias got='git '
alias get='git '

# qfind - used to quickly find files that contain a string in a directory
qf () {
    find . -exec grep -l -s $1 {} \;
    return 0
}

# Custom exports
## Set EDITOR to /usr/bin/vim if Vim is installed
if [ -f /usr/bin/vim ]; then
    export EDITOR=/usr/bin/vim
fi


# bind UP and DOWN arrow keys
zmodload zsh/terminfo
bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down


# source /usr/local/bin/virtualenvwrapper.sh


alias python="python3"
alias pip="pip3"
alias python="python3"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/rog/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/rog/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/Users/rog/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/rog/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<
# Download Znap, if it's not there yet.
[[ -r ~/Repos/znap/znap.zsh ]] ||
    git clone --depth 1 -- \
        https://github.com/marlonrichert/zsh-snap.git ~/Repos/znap
source ~/Repos/znap/znap.zsh  # Start Znap

# Download Znap, if it's not there yet.
[[ -r ~/Repos/znap/znap.zsh ]] ||
    git clone --depth 1 -- \
        https://github.com/marlonrichert/zsh-snap.git ~/Repos/znap
source ~/Repos/znap/znap.zsh  # Start Znap

# Added by Amplify CLI binary installer
export PATH="$HOME/.amplify/bin:$PATH"
