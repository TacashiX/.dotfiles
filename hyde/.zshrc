# Add user configurations here
# For HyDE to not touch your beloved configurations,
# we added 2 files to the project structure:
# 1. ~/.hyde.zshrc - for customizing the shell related hyde configurations
# 2. ~/.zshenv - for updating the zsh environment variables handled by HyDE // this will be modified across updates

#  Plugins 
# oh-my-zsh plugins are loaded  in ~/.hyde.zshrc file, see the file for more information

unset -f command_not_found_handler
#  Aliases 
# Add aliases here
alias vim='nvim'
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias ll='ls -la'
alias lt='ls --tree'
alias un='$aurhelper -Rns'

#  This is your file 
# Add your configurations here
export EDITOR=nvim
# export EDITOR=code
# setopt INC_APPEND_HISTORY
# setopt SHARE_HISTORY
# setopt HIST_EXPIRE_DUPS_FIRST
# setopt HIST_IGNORE_DUPS

# HISTSIZE=1000
# SAVEHIST=1000

# precmd(){
#   fc -A
# }
