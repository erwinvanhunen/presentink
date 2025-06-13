# PresentInk

**PresentInk** is a modern, menu bar–first screen annotation and presentation tool for macOS.  
Quickly draw, highlight, and focus attention on any part of your screen during presentations, meetings, or screen sharing.  
Lightweight, always accessible, and fully optimized for Mac.

---

![PresentInk Logo](icon_128x128.png) <!-- Add your logo image here -->

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


---

## 🚀 Installation

1. [Download the latest release](https://github.com/yourusername/presentink/releases)  
   *(or clone this repo and run locally; see “Development” below)*

2. **Run the app.**  
   You’ll find the PresentInk icon in your macOS menu bar. Click it for settings, help, or to quit.

---

## 🖱️ Usage & Hotkeys

| Key Combo                          | Action                        |
|-------------------------------------|-------------------------------|
| <kbd>Cmd</kbd> + 1 | Toggle Zoom mode. This effectively executes Cmd + Option + 8, which is the built-in zoom functionality of MacOS |
| <kbd>Option</kbd> + <kbd>Shift</kbd> + <kbd>D</kdb>     | Toggle drawing mode         |
 <kbd>Esc</kdb>     | Leave drawing mode         |
| <kbd>Shift</kbd>     | Draw straight lines            |
| <kbd>Cmd</kbd> + <kbd>Shift</kbd>      | Draw arrows mode              |
| <kbd>Cmd</kbd>     | Draw rectangles          |
| <kbd>Option</kbd>  | Draw ellipses |
| <kbd>Cmd</kbd> + <kbd>E</kdb> | Clear all drawings but stay in draw mode |
| <kbd>Cmd</kbd> + <kbd>Z</kbd>      | Undo last action              |
| <kbd>Right-click</kbd>              | Exit drawing mode             |
| <kbd>Option</kbd> + <kbd>Shift</kdb> + <kdb>B</kdb>                     | Start break timer     |
| <kbd>Up</kbd> | Increase line width    |
| <kbd>Down</kbd> | Decrease line width    |
| <kdb>ESC</kdb> | Exit break timer |

## Auto Typing
There is preliminary support for auto typing based upon a script, which uses the same format as the ZoomIt script format. E.g. it supports tags like [up],[down],[left],[right],[enter] and [end]. It uses a binary MacOS application to type, which is called PresentInkTyper, and you will be required to grant permissions to this application when using the auto typing functionality. You can load a script using the menu of PresentInk. Notice that this is an EARLY implementation and I've seen already some issues with cursor movement not working as correct. 
## ⚙️ Development

1. **Clone the repo:**
    ```bash
    git clone https://github.com/erwinvanhunen/presentink.git
    cd presentink
    ```

2. **Install dependencies:**
    ```bash
    npm install
    ```

3. **Start the app (dev mode):**
    ```bash
    npm start
    ```

**Recommended:**  
Use Node 18+ and Electron 24+.  

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

- Built with [Electron](https://electronjs.org)
- Inspired by [ZoomIt](https://docs.microsoft.com/en-us/sysinternals/downloads/zoomit)

---

<p align="center"><img src="icon_128x128.png" alt="PresentInk logo" width="64"></p>
