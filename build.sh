#!/bin/bash
set -e

VERSION="${1:-dev}"

echo "Creating directory structure..."
mkdir -p terminal-notifier.app/Contents/MacOS
mkdir -p terminal-notifier.app/Contents/Resources

echo "Copying Info.plist..."
cp Info.plist terminal-notifier.app/Contents/Info.plist

if [ "$VERSION" != "dev" ]; then
    plutil -replace CFBundleShortVersionString -string "$VERSION" terminal-notifier.app/Contents/Info.plist
    plutil -replace CFBundleVersion -string "$VERSION" terminal-notifier.app/Contents/Info.plist
fi

echo "Generating version file..."
echo "let APP_VERSION = \"${VERSION}\"" > Version.swift

echo "Compiling Swift code..."
swiftc -O -o terminal-notifier.app/Contents/MacOS/terminal-notifier main.swift Version.swift

echo "Ad-hoc code signing binary..."
codesign --force --sign - terminal-notifier.app/Contents/MacOS/terminal-notifier

echo "Ad-hoc code signing bundle..."
codesign --force --sign - terminal-notifier.app

echo "Build complete! terminal-notifier.app is ready."
