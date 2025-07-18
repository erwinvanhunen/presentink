# PresentInk

**PresentInk** is a modern, menu bar–first screen annotation and presentation tool for macOS.  
Quickly draw, highlight, and focus attention on any part of your screen during presentations, meetings, or screen sharing.  
Lightweight, always accessible, and fully optimized for Mac.

---

![PresentInk Logo](PresentInk/Assets.xcassets/logo256x256.imageset/icon_256x256.png) 

---

## ✨ Features

- **Freehand Drawing** — Annotate with a smooth pen tool in your chosen color.
- **Arrows, Boxes, Ellipses** — Draw professional shapes, arrows, rectangles, or ellipses to direct focus.
- **Straight Lines & Perfect Shapes** — Hold Shift to constrain lines/shapes.
- **Undo Support** — Instantly undo your last action with `Cmd+Z`.
- **Break Timer** — Launch a distraction-free, full-screen break timer with one keystroke.
- **Minimal Menu Bar Icon** — PresentInk stays out of your Dock, always available from your Mac’s menu bar.
- **Multi-Screen Aware** — Works across all your displays.
- **Available when you need it** - PresentInk can be set to launch on login, ready when you need it with a single keypress.
- **Easily take screenshots** - Take rectangular screenshots with an easy to remember shortcut. 


---

## 🚀 Installation

1. [Download the latest release](https://github.com/erwinvanhunen/presentink/releases)  
   *(or clone this repo and run locally; see “Development” below)*

2. **Run the app.**  
   You’ll find the PresentInk icon in your macOS menu bar. Click it for settings, help, or to quit.

---

## 🖱️ Usage & Hotkeys

| Key Combo                          | Action                        |
|-------------------------------------|-------------------------------|
| <kbd>Option</kbd> + <kbd>Shift</kbd> + <kbd>D</kdb>     | Toggle drawing mode         |
| <kbd>Option</kbd> + <kbd>Shift</kbd> + <kbd>S</kdb>     | Take a screenshot         |
 <kbd>Esc</kdb>     | Leave drawing mode or breaktimer if active        |
| <kbd>Shift</kbd>     | Draw straight lines            |
| <kbd>Cmd</kbd> + <kbd>Shift</kbd>      | Draw arrows mode              |
| <kbd>Cmd</kbd>     | Draw rectangles          |
| <kbd>Option</kbd>  | Draw ellipses |
| <kbd>E</kdb> | Clear all drawings but stay in draw mode |
| <kbd>Cmd</kbd> + <kbd>Z</kbd>      | Undo last action              |
| <kbd>Right-click</kbd>              | Exit drawing mode             |
| <kbd>Option</kbd> + <kbd>Shift</kdb> + <kdb>B</kdb>                     | Start break timer     |
| <kbd>Up</kbd> | Increase line width    |
| <kbd>Down</kbd> | Decrease line width    |

## Text Typer / Auto Typing
There is preliminary support for auto typing based upon a script, which uses the same format as the ZoomIt script format. E.g. it supports tags like [up],[down],[left],[right],[enter] and [end]. Activate this functionality in the settings by turning on 'Experimental features'. Create a text file with your text, and separate the entries with [end].

```
This is the first line. I will have to press the shortcut again to show the next line[end]
I pressed the shortcut [pause:3] and I just paused 3 seconds[end]
[up]Now I went a line up and continue to type[end]
```
Select the text file from the Text Typer menu. Move the cursor to a program where you can type text (PresentInk does not check that, it will simply start to type after you pressed the shortcut), and press the shortcut Option+Shift+T (or the one you configured in the settings).

The text will cycle back to the first line after the last entry has been 'typed'. 
---

## 🤝 Contributing

Pull requests and suggestions are welcome!  
For major changes, please open an issue first to discuss what you’d like to change.

- Fork the repo
- Create a new branch (`git checkout -b feature/my-feature`)
- Commit your changes
- Push to your fork and open a pull request

---

## 📄 License

MIT License  
© 2025 Erwin van Hunen

---

## 💡 Credits

- Inspired by [ZoomIt](https://docs.microsoft.com/en-us/sysinternals/downloads/zoomit)

---

<p align="center"><img src="icons/presentink.iconset/icon_128x128.png" alt="PresentInk logo" width="64"></p>