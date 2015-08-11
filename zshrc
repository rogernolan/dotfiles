
export PATH=$PATH:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:~/bin

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


source /usr/local/bin/virtualenvwrapper.sh


NPM_PACKAGES=/Users/rog/.npm-packages
NODE_PATH="$NPM_PACKAGES/lib/node_modules:$NODE_PATH"
PATH="$NPM_PACKAGES/bin:$PATH"
NODE_PATH="$NPM_PACKAGES/lib/node_modules:$NODE_PATH"

. ~/.nvm/nvm.sh


alias gulp="gulp --harmony --harmony_arrow_functions"


source ~/.xsh

