### Dotfiles

#### Arch

```
pacman -Syu
pacman -S base-devel git go zsh curl tmux alacritty stow xclip make gcc ripgrep unzip neovim bc gawk jq playerctl nodejs gopls nerd-fonts wl-clipboard fzf
```

Hyprland machines: 
```
sudo pacman -S hyprland xdg-desktop-portal-hyprland wayland wlroots rofi-wayland waybar swaylock wlogout grim slurp xorg-xwayland ttf-font-awesome imagemagick hyprpaper swaync pipewire pipewire-alsa pipewire-pulse pavucontrol nemo blueman alsa-utils nm-connection-editor hyprshot
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
Clone zsh plugins into config manually

Uncomment multilib lines in '/etc/pacman.conf' then 'sudo pacman -Sy'

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
