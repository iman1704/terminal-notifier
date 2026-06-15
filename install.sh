#!/bin/bash
set -e

# 1. Build the app bundle to ensure it's up to date
./build.sh

INSTALL_DIR="/usr/local/share/terminal-notifier"
BIN_DIR="/usr/local/bin"

echo "Installing terminal-notifier.app to $INSTALL_DIR..."
sudo mkdir -p "$INSTALL_DIR"
sudo cp -R terminal-notifier.app "$INSTALL_DIR/"

echo "Creating symlink in $BIN_DIR..."
sudo mkdir -p "$BIN_DIR"
sudo ln -sf "$INSTALL_DIR/terminal-notifier.app/Contents/MacOS/terminal-notifier" "$BIN_DIR/terminal-notifier"

echo "Registering application with LaunchServices..."
open "$INSTALL_DIR/terminal-notifier.app"

echo "Installation complete! You can now run 'terminal-notifier' from anywhere."
