#!/bin/zsh
# Starts the cycling app (Godot project in game/). Double-click in Finder.
cd "${0:A:h}/game"
exec /Applications/Godot.app/Contents/MacOS/Godot --path .
