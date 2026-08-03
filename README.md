# sway-installer

Minimal sway tiling compositor setup for Ubuntu 26.04+.

Installs and configures sway with a small, focused set of tools and a consistent Nord-ish dark theme across all components.

## What gets installed

| Package | Purpose |
|---|---|
| `sway` + `swaybg` | Wayland compositor + wallpaper |
| `swayidle` + `swaylock` | Idle timeout and lock screen |
| `waybar` | Status bar |
| `wofi` | Application launcher |
| `foot` | Terminal emulator |
| `mako-notifier` | Notification daemon |
| `grimshot` | Screenshot tool |
| `wl-clipboard` | Clipboard (`wl-copy` / `wl-paste`) |
| `xdg-desktop-portal-wlr` | Screen sharing support |
| `fonts-jetbrains-mono` | Font used across all components |

## Config files

```
config/
├── sway/config         # Main sway config — keybindings, gaps, colours, idle
├── waybar/config       # Bar layout and modules
├── waybar/style.css    # Bar theme
├── wofi/style.css      # Launcher theme
├── foot/foot.ini       # Terminal — font, colours, scrollback
└── mako/config         # Notifications — position, timeout, urgency colours
```

Files are copied to `~/.config/<app>/` by the installer. Existing files are backed up to `<file>.bak` before being overwritten.

## Usage

```bash
git clone https://github.com/youruser/sway-installer ~/gits/sway-installer
cd ~/gits/sway-installer
./setup-sway.sh
```

Then log out and select **Sway** at the GDM login screen.

## After install

### Wallpaper

Edit `~/.config/sway/config` and replace the solid colour background:

```
output * bg /path/to/your/image.jpg fill
```

### Multiple monitors

Run `swaymsg -t get_outputs` to get your output names, then uncomment and adapt the output section in `~/.config/sway/config`:

```
output HDMI-A-1 resolution 1920x1080 position 0,0
output eDP-1    resolution 1920x1080 position 0,1080
```

### Brightness keys

Brightness control requires `brightnessctl`:

```bash
sudo apt install brightnessctl
sudo usermod -aG video $USER   # log out and back in after this
```

### Screen sharing

Firefox, Chrome, and other apps use `xdg-desktop-portal-wlr` for screen sharing. If it doesn't work after install, log out and back in.

## Key bindings

| Key | Action |
|---|---|
| `Super+Enter` | Terminal (foot) |
| `Super+d` | Launcher (wofi) |
| `Super+l` | Lock screen |
| `Super+Shift+q` | Kill focused window |
| `Super+Shift+e` | Exit sway |
| `Super+Shift+r` | Reload config |
| `Super+r` | Resize mode |
| `Super+f` | Fullscreen |
| `Super+Shift+Space` | Toggle floating |
| `Super+hjkl` / arrows | Focus direction |
| `Super+Shift+hjkl` | Move window |
| `Super+1–9` | Switch workspace |
| `Super+Shift+1–9` | Move window to workspace |
| `Super+Shift+minus` | Send to scratchpad |
| `Super+minus` | Show scratchpad |
| `Print` | Screenshot area (copy) |
| `Super+Print` | Screenshot window (copy) |
| `Shift+Print` | Screenshot area (save to ~/Pictures) |

## Idle / lock behaviour

| Trigger | Action |
|---|---|
| 5 min idle | Lock screen |
| 10 min idle | Turn off displays |
| 11 min idle | Suspend |
| Lid close | Lock screen |
| Before sleep | Lock screen |
