# notes.koplugin

`notes.koplugin` is a plugin for KOReader to write handwritten notes.

## How to install?
Download this project as .zip file and extract into KOReader's plugin directory

## How to use it?
Once the app is loaded, you will see the `NEW: Notes` option under the tools menu. 

Draw using a stylus/hand in the canvas area.

Use the `<`,`>` icons inside the dialog window to change pages - new page will be created when needed.

Click the `X` icon at the top-right to close the plugin. (The notes will still be in memory when you open the plugin again)

Use the hamburger menu at the top-left to save the notes to a directory as png files.


## Project Goals
1. [x] Simple app to take notes while reading technical books.
2. [x] Support multi page notes 
3. [x] Save into storage as simple image files (.png)
4. [x] Load notes from storage
5. [ ] Multi-color pens
6. [ ] Eraser (supports kobo stylus, no icon to select eraser at the moment)
7. [x] Clear page ~~/whole notes~~
8. [x] Setup a background / template for page

## Features not planned at the moment
1. Support undo/redo
2. Storing as vector graphics formats (svg, excalibre etc.)
3. Zoom-in/Zoom-out/pan
4. Palm rejection
5. Change canvas size when device is rotated

## Devices tested 
1. I am using my `Kobo Libra 2 Colour` with `Kobo stylus` for development and testing
2. I have an old `Samsung Galaxy Tab 3` and `stylus` which I can use to test Android (At the moment the app is making KOReader app itself to crash)

## How does it work 

When the plugin is visible, the gesture-detector in the core device/input  object is swapped out with a an interceptor, to get access to the touch events parsed by it.
The reason we have to do this is because the core doesn't give a mechanism to read the parsed touch events from input module.


# Known Issues
1. The Koreader app crashes in Android after using the plugin for some time. Not have had the time to debug that. 