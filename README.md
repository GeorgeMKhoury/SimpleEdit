# SimpleEdit

A native macOS SimpleEdit clone built with Swift and AppKit.

## Features
- Find/Replace
- Word Wrap
- Font Persistence

## Build Instructions

To build the application bundle, run the following commands:

```bash
mkdir -p SimpleEdit.app/Contents/MacOS
mkdir -p SimpleEdit.app/Contents/Resources
cp Info.plist SimpleEdit.app/Contents/Info.plist
cp AppIcon.icns SimpleEdit.app/Contents/Resources/AppIcon.icns
swiftc SimpleEdit.swift -o SimpleEdit.app/Contents/MacOS/SimpleEdit
```

## Running the App
After building, you can open the app by running:
```bash
open SimpleEdit.app
```
