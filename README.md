# NativeNotepad

A native macOS Notepad clone built with Swift and AppKit.

## Features
- Find/Replace
- Word Wrap
- Font Persistence

## Build Instructions

To build the application bundle, run the following commands:

```bash
mkdir -p NativeNotepad.app/Contents/MacOS
mkdir -p NativeNotepad.app/Contents/Resources
cp Info.plist NativeNotepad.app/Contents/Info.plist
cp AppIcon.icns NativeNotepad.app/Contents/Resources/AppIcon.icns
swiftc Notepad.swift -o NativeNotepad.app/Contents/MacOS/NativeNotepad
```

## Running the App
After building, you can open the app by running:
```bash
open NativeNotepad.app
```
