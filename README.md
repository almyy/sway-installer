# sway-installer

Minimal sway tiling compositor setup for Ubuntu 26.04+.

Installs and configures sway with a small, focused set of tools and a consistent theme across all components. Pick from four themes at install time.

## What gets installed

| Package | Purpose |
|---|---|
| `sway` + `swaybg` | Wayland compositor + wallpaper |
| `swayidle` + `swaylock` | Idle timeout and lock screen |
| `waybar` | Status bar |
| `wofi` | Application launcher |
| `foot` | Terminal emulator |
| `mako-notifier` | Notification daemon |
| `grimshot` + `swappy` | Screenshot capture + annotation |
| `wl-clipboard` | Clipboard (`wl-copy` / `wl-paste`) |
| `xdg-desktop-portal-wlr` | Screen sharing support |
| `network-manager-gnome` | Wi-Fi / VPN tray applet (`nm-applet`) |
| `blueman` | Bluetooth tray applet |
| `nwg-bar` | Power menu (lock / logout / reboot / shutdown) |
| `nwg-displays` | Graphical monitor layout editor |
| `gnome-keyring` + `libpam-gnome-keyring` | Secret storage, unlocked at login |
| `fonts-jetbrains-mono` | Font used across all components |

Already-installed packages are skipped.

## Usage

```bash
git clone https://github.com/youruser/sway-installer ~/gits/sway-installer
cd ~/gits/sway-installer
./setup-sway.sh
```

Pass `--dry-run` to see every action without changing anything.

The installer asks three questions:

| Prompt | Options | Default |
|---|---|---|
| Theme | Nord, Gruvbox, Catppuccin, Solarized Light | Nord |
| Gap size | None, Small (4/2), Medium (8/4), Large (16/8) | Medium |
| Bar placement | Bottom, Top | Bottom |

Choosing **None** for gaps also disables window borders.

Then log out and select **Sway** at the GDM login screen.

## Repository layout

```
config/                     # theme-independent, shared by all themes
├── sway/config             # keybindings, gaps, colours, idle, autostart
├── waybar/config           # bar layout and modules
└── nwg-bar/bar.json        # power menu entries

themes/<name>/              # one directory per theme
├── sway-theme.conf         # colour variables read by the installer
├── waybar/style.css        # bar theme
├── wofi/style.css          # launcher theme
├── foot/foot.ini           # terminal — font, colours, scrollback
└── mako/config             # notifications — position, timeout, urgency colours
```

Files land in `~/.config/<app>/`. On the first run an existing file is moved to `<file>.bak`; later runs overwrite without touching that backup, so `.bak` always holds your pre-installer config.

`config/sway/config` is a complete Nord-themed config that the installer patches in place after copying — theme colours, gap sizes, and border style are substituted into the copy under `~/.config`. `config/waybar/config` gets its `position` patched the same way.

The installer also adds `pam_gnome_keyring` to `/etc/pam.d/gdm-password` (backed up to `gdm-password.bak`) so your keyring unlocks with your login password. This step is skipped if the PAM file is missing, and is safe to re-run.

## After install

### Wallpaper

```bash
swaymsg "output * bg /path/to/image fill"
```

To make it permanent, edit the `output * bg` line in `~/.config/sway/config`.

### Multiple monitors

Run `nwg-displays` for a drag-and-drop layout editor. It writes your arrangement to `~/.config/sway/outputs`, which `~/.config/sway/config` already includes, so it survives restarts.

To do it by hand instead, run `swaymsg -t get_outputs` for your display names, then add lines like:

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

Firefox, Chrome, and other apps use `xdg-desktop-portal-wlr`. If it doesn't work after install, log out and back in.

### Keyboard layout

`config/sway/config` sets a Norwegian layout (`xkb_layout no`) and maps Caps Lock to Escape. Change the `input type:keyboard` block if you want something else.

## Key bindings

`Super` is the modifier throughout.

### Launching and session

| Key | Action |
|---|---|
| `Super+Enter` | Terminal (foot) |
| `Super+d` | Launcher (wofi) |
| `Super+l` | Lock screen |
| `Super+Shift+p` | Power menu (nwg-bar) |
| `Super+Shift+q` | Kill focused window |
| `Super+Shift+r` | Reload config |
| `Super+Shift+e` | Exit sway (with confirmation) |

### Focus and movement

| Key | Action |
|---|---|
| `Super+arrows` | Focus direction |
| `Super+Shift+arrows` | Move window |
| `Super+a` | Focus parent container |
| `Super+Space` | Toggle focus between tiled and floating |
| `Super+1`–`9` | Switch workspace |
| `Super+Shift+1`–`9` | Move window to workspace |
| `Super+Ctrl+Shift+Left/Right` | Move whole workspace to another output |
| `Super+Shift+minus` | Send window to scratchpad |
| `Super+minus` | Show scratchpad |

### Layout

| Key | Action |
|---|---|
| `Super+b` / `Super+v` | Split horizontal / vertical |
| `Super+s` / `Super+w` | Stacking / tabbed layout |
| `Super+e` | Toggle split direction |
| `Super+f` | Fullscreen |
| `Super+Shift+Space` | Toggle floating |
| `Super+r` | Resize mode — arrows resize, `Enter` or `Escape` exits |

### Screenshots

All three capture to `swappy` for annotation, where you can copy or save.

| Key | Action |
|---|---|
| `Print` | Select an area |
| `Super+Print` | Focused window |
| `Shift+Print` | Whole screen |

### Media keys

Volume and mic mute go through `wpctl` (PipeWire); brightness needs `brightnessctl` as described above.

## Idle / lock behaviour

| Trigger | Action |
|---|---|
| 5 min idle | Lock screen |
| 10 min idle | Turn off displays |
| 11 min idle | Suspend |
| Lid close | Lock screen |
| Before sleep | Lock screen |

## Adding a theme

Copy an existing directory under `themes/`, adjust the colours in all five files, then add a menu entry and a `case` branch to the theme-selection block in `setup-sway.sh`.
