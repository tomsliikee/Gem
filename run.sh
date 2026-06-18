#!/bin/bash
cd "/home/toms/projects/Gem"

# WebKit optimization flags for Linux
export WEBKIT_DISABLE_COMPOSITING_MODE=0
export WEBKIT_FORCE_SANDBOX=0
export WEBKIT_USE_SINGLE_WEB_PROCESS=1

./build/linux/x64/release/bundle/gem
