# if type "xrandr"; then
#   for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
#     MONITOR=$m polybar --reload example &
#   done
# else
#   polybar --reload example &
# fi

#!/bin/sh
MONITORS=$(xrandr --query | grep " connected" | cut -d" " -f1)
MONITOR=$MONITORS polybar --reload example &
