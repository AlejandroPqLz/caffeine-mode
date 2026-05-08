# caffeine-mode

Minimal macOS menu bar app to prevent sleep with two configurable modes.

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

```bash
cp -r build/caffeine-mode.app ~/Applications/
```

Then open the app and enable **Settings > Launch at Login**.

## Usage

1. Build and open the app
2. Coffee cup icon (`cup.and.saucer.fill`) appears in the menu bar
3. Click the icon to open the menu
4. Click a mode to activate it — click again to stop

The icon is tinted blue or orange while a mode is active. Hover over a mode to see a tooltip with the underlying command.

## Modes

| Mode | Command | Effect | Color |
|------|---------|--------|-------|
| **Long Runs** | `caffeinate -di` | Prevents idle sleep and display sleep. Disk may still sleep. | Blue |
| **ML Training** | `caffeinate -dim` | Blocks all sleep: system, display, and disk. | Orange |

Switching modes stops the current one and starts the new one immediately.

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Launch at Login | Off | Auto-start on login via `SMAppService` |
| Hide from Dock | On | App appears only in the menu bar |

## Troubleshooting

**macOS blocks app after rebuild (code signature mismatch):**
```bash
codesign --remove-signature build/caffeine-mode.app
```

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
