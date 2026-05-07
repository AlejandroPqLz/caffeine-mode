# CaffeineMode — Caffeinate Menu Bar macOS

Minimal menu bar app to prevent macOS sleep with three configurable modes.

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
| **Clamshell w/o AC** | `sudo pmset -a disablesleep 1` | Keeps Mac awake with lid closed, no AC required. Requires admin password once. |
| **Long Runs** | `caffeinate -di` | Prevents idle sleep and screen off. Disk may sleep. |
| **ML Training** | `caffeinate -dim` | Blocks all sleep: system, screen, and disk. |

Clicking an active mode again stops it. All changes are reversed on stop.

### Colors

- Green: Clamshell w/o AC
- Yellow: Long Runs
- Red: ML Training

### Settings (Settings submenu)

| Setting | Default | Description |
|---------|---------|-------------|
| Launch at Login | Off | Auto-start on login |
| Hide from Dock | On | App only visible in menu bar and not in Force Quit |
| Show Warnings | On | Show alert before activating Clamshell w/o AC |

## Clamshell w/o AC — Admin Password

The first time you activate this mode, the app writes a sudoers rule so `pmset` can run without a password prompt on all future uses:

```
/etc/sudoers.d/caffeinemode
<username> ALL=(ALL) NOPASSWD: /usr/bin/pmset
```

You will see a macOS admin password dialog once. After that, no password is ever needed again — even after restarts.

To remove this permission manually:

```bash
sudo rm /etc/sudoers.d/caffeinemode
```

### Important: Force Quit behavior

If the app is force-quit (not a clean Quit) while **Clamshell w/o AC** is active, `disablesleep` remains set to `1`. To restore normal sleep behavior manually:

```bash
sudo pmset -a disablesleep 0
```

## Dock visibility

The app starts hidden from the Dock by default (`LSUIElement = true` in Info.plist). Toggle via **Settings > Hide from Dock**.

If macOS blocks the app after a rebuild due to code signature mismatch, run once:

```bash
codesign --remove-signature build/caffeine-mode.app
```

This only needs to be done once after each rebuild if the signature check fails.

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

**pmset disablesleep stuck at 1:**
```bash
sudo pmset -a disablesleep 0
```
