# MY FOLDERS
export WORK="$HOME/Thinktecture/Repos"
export PRIVATE="$HOME/Slash-IT/Repos"
export DOTFILES="$PRIVATE/dotfiles/"

alias tt="cd $WORK"
alias pp="cd $PRIVATE"
alias df="cd $DOTFILES"

# PATH
PATH="${PATH}:/usr/local/sbin"

# dotnet tools
PATH="${PATH}:$HOME/.dotnet/tools"

# personal executables
PATH="${PATH}:$HOME/.bin"

# nvm
export NVM_DIR="$HOME/.nvm"
lazynvm() {
  unset -f nvm node npm npx nvim
  export NVM_DIR=~/.nvm
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" # This loads nvm
  if [ -f "$NVM_DIR/bash_completion" ]; then
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
  fi
}

nvm() {
  lazynvm
  nvm $@
}

node() {
  lazynvm
  node $@
}

npm() {
  lazynvm
  npm $@
}

npx() {
  lazynvm
  npx $@
}

nvim() {
  if [ -f "package.json" ]; then
    lazynvm
  fi
  command nvim $@
}

# make path available
export PATHs

# Make vim the default editor
export EDITOR='nvim'

#NVM

export NVM_DIR="$HOME/.nvm"
[ -s "/usr/local/opt/nvm/nvm.sh" ] && \. "/usr/local/opt/nvm/nvm.sh"
[ -s "/usr/local/opt/nvm/etc/bash_completion" ] && \. "/usr/local/opt/nvm/etc/bash_completion"
