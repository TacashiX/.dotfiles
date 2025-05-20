#!/usr/bin/env bash

if pgrep -x "wlogout" >/dev/null; then
    pkill -x "wlogout"
    exit 0
fi

confDir="${confDir:-$HOME/.config}"
wLayout="${confDir}/wlogout/layout_1"
wlTmplt="${confDir}/wlogout/style_1.css"
# blurImg="/tmp/wlogout_blur.png"


# Get the current wallpaper from Hyprland
# wallpaper=$(hyprctl -j monitors | jq -r '.[] | select(.focused==true) | .wallpaper')
# wallpaper=$(hyprctl hyprpaper listactive | awk '{print $3}')
# blurImg="${wallpaper%/*}/blr_${wallpaper##*/}"
#
# if [ -f "$blurImg" ]; then 
#     export blrBg="$blurImg"
# else
#     # If wallpaper is not directly available, fallback to capturing the screen
#     if [ -z "$wallpaper" ] || [ ! -f "$wallpaper" ]; then
# 	grim - | magick - -blur 0x16 "$blurImg"
#     else
# 	# Blur the wallpaper
# 	magick "$wallpaper" -blur 0x16 "$blurImg"
#     fi
#     export blrBg="$blurImg"
# fi
#
x_mon=$(hyprctl -j monitors | jq '.[] | select(.focused==true) | .width')
y_mon=$(hyprctl -j monitors | jq '.[] | select(.focused==true) | .height')
hypr_scale=$(hyprctl -j monitors | jq '.[] | select (.focused == true) | .scale' | sed 's/\.//')

wlColms=6
export mgn=$((y_mon * 28 / hypr_scale))
export hvr=$((y_mon * 23 / hypr_scale))
export fntSize=$((y_mon * 2 / 100))
export BtnCol="white"

hypr_border="${hypr_border:-10}"
export active_rad=$((hypr_border * 5))
export button_rad=$((hypr_border * 8))

# Extract @main-bg from theme.css and convert to RGB
main_bg=$(grep '@define-color main-bg' "${confDir}/waybar/theme.css" | sed 's/.*#//;s/;//')
# Convert hex to RGB
r=$((16#${main_bg:0:2}))
g=$((16#${main_bg:2:2}))
b=$((16#${main_bg:4:2}))
export main_bg_rgb="${r}, ${g}, ${b}"

wlStyle="$(envsubst <"${wlTmplt}")"

wlogout -b "${wlColms}" -c 0 -r 0 -m 0 --layout "${wLayout}" --css <(echo "${wlStyle}") --protocol layer-shell

# rm -f "$blurImg"
