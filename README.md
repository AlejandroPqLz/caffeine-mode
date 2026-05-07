# CaffeineMode — Caffeinate Menu Bar macOS

Minimal menu bar app to prevent macOS sleep with two configurable modes.

> **Clamshell mode** (lid closed without AC) has been moved to its own app: [free-clamshell-mode](https://github.com/AlejandroPqLz/free-clamshell-mode)

## Requirements

- macOS 11.0+
- Swift 5.5+
- Terminal

## Build

```bash
bash build.sh
```

Output: `build/caffeine-mode.app`

## Install (optional)

To run at login, copy to Applications:

```bash
cp -r build/caffeine-mode.app ~/Applications/
```

Then open the app and enable **Settings > Launch at Login**.

## Usage

1. Build and open the app
2. Coffee icon appears in the menu bar
3. Click the icon to open the menu

### Modes

| Mode | Command | Effect |
|------|---------|--------|
| **Long Runs** | `caffeinate -di` | Prevents idle sleep and screen off. Disk may sleep. |
| **ML Training** | `caffeinate -dim` | Blocks all sleep: system, screen, and disk. |

Clicking an active mode again stops it.

### Colors

- Yellow: Long Runs
- Red: ML Training

### Settings (Settings submenu)

| Setting | Default | Description |
|---------|---------|-------------|
| Launch at Login | Off | Auto-start on login |
| Hide from Dock | On | App only visible in menu bar and not in Force Quit |

## Dock visibility

The app starts hidden from the Dock by default (`LSUIElement = true` in Info.plist). Toggle via **Settings > Hide from Dock**.

If macOS blocks the app after a rebuild due to code signature mismatch, run once:

```bash
codesign --remove-signature build/caffeine-mode.app
```

## Troubleshooting

**"Permission denied":**
```bash
chmod +x build/caffeine-mode.app/Contents/MacOS/caffeine-mode
```

**"Compilation failed":**
```bash
xcode-select --install
```

**caffeinate still running after stop:**
```bash
killall caffeinate
```
