### Dotfiles

Add NVIM ppa:
```
sudo add-apt-repository ppa:neovim-ppa/unstable -y
sudo apt update
```

Install requirements: 
``` 
sudo apt install golang i3 zsh curl tmux fonts-powerline picom rofi alacritty polybar stow git xclip make gcc ripgrep unzip neovim bash bc coreutils gawk jq playerctl -y
```

Install [fonts](https://github.com/powerline/fonts): 
```
git clone https://github.com/powerline/fonts.git --depth=1
./fonts/install.sh
rm -rf fonts
```

Make zsh default:
```
chsh -s $(which zsh)
```

Install [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh):
```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

[Powerlevel10k](https://github.com/romkatv/powerlevel10k):
``` 
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
```

[Tmux plugin manager](https://github.com/tmux-plugins/tpm): 
```
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```
*`<Leader> + I` to install plugins*

`stow` config directories you need. 
