#!/bin/bash
set -e

echo "Creating directory structure..."
mkdir -p terminal-notifier.app/Contents/MacOS
mkdir -p terminal-notifier.app/Contents/Resources

echo "Compiling Swift code..."
swiftc -O -o terminal-notifier.app/Contents/MacOS/terminal-notifier main.swift

echo "Ad-hoc code signing binary..."
codesign --force --sign - terminal-notifier.app/Contents/MacOS/terminal-notifier

echo "Ad-hoc code signing bundle..."
codesign --force --sign - terminal-notifier.app

echo "Build complete! terminal-notifier.app is ready."
