#!/bin/bash

#simple script to start and exit gpu-screen-recorder with steam games
#Set Steam launch options to 'bash -c "~/.dotfiles/misc/game-replay.sh %command%"'
#or combine with other options 'bash -c "~/.dotfiles/misc/game-replay.sh LD_PRELOAD='' gamemoderun %command%"'
#add 'killall -SIGUSR1 gpu-screen-recorder' to your system shortcuts for easy replay saving


#gpu-screen-recorder options, check --help
DISPLAY="DP-2"
AUDIO="app:PathOfExileSteam.exe" #for all audio use default_audio
REPLAY_SECONDS=120
VIDEO_DIRECTORY="$HOME/Videos/gpu-screen-record"
VIDEO_QUALITY="very_high"

# Start screen recorder in background
gpu-screen-recorder -w $DISPLAY -a $AUDIO -q $VIDEO_QUALITY -f 60 -r $REPLAY_SECONDS -c mp4 -o $VIDEO_DIRECTORY #&
#RECORDER_PID=$!

# Launch the game with Steam's arguments
# echo "launching: $@" > ~/.dotfiles/misc/debug.txt
# exec "$@"

# Stop the screen recorder and F4 monitoring when the game exits
# kill $RECORDER_PID

