#!/bin/bash

# Function to safely stop background processes
stop_bg_processes() {
    if pgrep -f "playbgm.sh" >/dev/null; then
        killall -q "playbgm.sh" "mp3play"
    fi

    if pgrep -f "muplay" >/dev/null; then
        killall -q "muplay"
        [ -n "$SND_PIPE" ] && rm "$SND_PIPE"
    fi
}

# Stop background processes locally or remotely
stop_bg_processes

# Set activity to 'app'
echo app >/tmp/act_go

# Source necessary scripts
. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")
SDL_SCALER=$(parse_ini "$DEVICE_CONFIG" "sdl" "scaler")

export SDL_HQ_SCALER="$SDL_SCALER"

# Define paths and commands
LOVEDIR="$STORE_ROM/MUOS/application/.dinojam"
GPTOKEYB="$STORE_ROM/MUOS/emulator/gptokeyb/gptokeyb2.armhf"
CONFDIR="$LOVEDIR/conf/"

# Export environment variables
export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib32/gamecontrollerdb.txt"
export XDG_DATA_HOME="$CONFDIR"

# Launcher
cd "$LOVEDIR" || exit
echo "love" >/tmp/fg_proc
export LD_LIBRARY_PATH="$LOVEDIR/libs:$LD_LIBRARY_PATH"
$GPTOKEYB "love" &
./love dinojam
kill -9 "$(pidof gptokeyb2.armhf)"
