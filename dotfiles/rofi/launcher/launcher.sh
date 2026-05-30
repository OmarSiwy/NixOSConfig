#!/usr/bin/env bash

dir="$HOME/.config/rofi/launcher/style"

## Run
env -u DISPLAY rofi \
    -show drun \
    -monitor -2 \
    -theme ${dir}.rasi
