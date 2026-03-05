# SimpleEdit

A native macOS clone of Notepad built with Swift and SwiftUI.

## Features
- Find/Replace
- Word Wrap
- Font Persistence
- Dark Mode
- Auto-save

## Build Instructions

To build the application bundle, run the following commands:

```bash
mkdir -p SimpleEdit.app/Contents/MacOS
mkdir -p SimpleEdit.app/Contents/Resources
cp Info.plist SimpleEdit.app/Contents/Info.plist
cp AppIcon.icns SimpleEdit.app/Contents/Resources/AppIcon.icns
swiftc -parse-as-library SimpleEdit.swift -o SimpleEdit.app/Contents/MacOS/SimpleEdit
```

## Running the App
After building, you can open the app by running:
```bash
open SimpleEdit.app
```
