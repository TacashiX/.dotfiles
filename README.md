### Dotfiles

#### Dependencies

<details>
<summary>Debian</summary>

Add NVIM ppa:
```
sudo add-apt-repository ppa:neovim-ppa/unstable -y
sudo apt update
```

Add Nodejs ppa:
```
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
```

Install requirements: 
``` 
sudo apt install golang i3 zsh curl tmux fonts-powerline picom rofi alacritty polybar stow git xclip make gcc ripgrep unzip neovim bash bc coreutils gawk jq playerctl autocutsel nodejs -y
```

Install [fonts](https://github.com/powerline/fonts): 
```
git clone https://github.com/powerline/fonts.git --depth=1
./fonts/install.sh
rm -rf fonts
```

if tmux/nvim icons dont show up install nerd fonts, should probably just switch to one of these but i can't be bothered right now
```
sudo apt install wget fontconfig \
&& wget -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip \
&& cd ~/.local/share/fonts && unzip Meslo.zip && rm *Windows* && rm Meslo.zip && fc-cache -fv
```

Install [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh):
```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

[Powerlevel10k](https://github.com/romkatv/powerlevel10k):
``` 
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
```

</details>

<details>
    <summary>Arch</summary>


```
pacman -Syu
pacman -S base-devel git go zsh curl tmux alacritty stow xclip make gcc ripgrep unzip neovim bc gawk jq playerctl nodejs gopls nerd-fonts wl-clipboard
```

Hyprland machines: 
```
sudo pacman -S hyprland xdg-desktop-portal-hyprland wayland wlroots rofi-wayland waybar swaylock wlogout grim slurp xorg-xwayland ttf-font-awesome
```

Install yay
```
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

Might want to install oh-my-zsh manually
```
yay -S autocutsel zsh-theme-powerlevel10k-git oh-my-zsh-git
```

Uncomment multilib lines in '/etc/pacman.conf' then 'sudo pacman -Sy'

</details>

Make zsh default (relog after change):
```
chsh -s $(which zsh)
```

[Tmux plugin manager](https://github.com/tmux-plugins/tpm): 
```
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```
*`<Leader> + I` to install plugins*

`stow` config directories you need. 
