#!/bin/bash
set -e

INSTALL_DIR="/usr/local/share/terminal-notifier"
BIN_DIR="/usr/local/bin"

echo "Removing symlink from $BIN_DIR..."
sudo rm -f "$BIN_DIR/terminal-notifier"

echo "Removing terminal-notifier.app from $INSTALL_DIR..."
sudo rm -rf "$INSTALL_DIR"

echo "Uninstall complete."
