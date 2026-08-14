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
| `wdisplays` | Graphical monitor layout editor |
| `jq` | JSON parsing, used by the output-profile daemon |
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
bin/                        # executables, installed to ~/.local/bin/
├── sway-output-profiles    # remembers a monitor layout per set of outputs
└── sway-docked             # lid and idle behaviour when an external display is connected

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

Config files land in `~/.config/<app>/` and `bin/` lands in `~/.local/bin/`. On the first run an existing config file is moved to `<file>.bak`; later runs overwrite without touching that backup, so `.bak` always holds your pre-installer config. Shipped executables are overwritten outright — they are ours, not yours.

`config/sway/config` is a complete Nord-themed config that the installer patches in place after copying — theme colours, gap sizes, and border style are substituted into the copy under `~/.config`. `config/waybar/config` gets its `position` patched the same way.

The installer also adds `pam_gnome_keyring` to `/etc/pam.d/gdm-password` (backed up to `gdm-password.bak`) so your keyring unlocks with your login password. This step is skipped if the PAM file is missing, and is safe to re-run.

## After install

### Wallpaper

```bash
swaymsg "output * bg /path/to/image fill"
```

To make it permanent, edit the `output * bg` line in `~/.config/sway/config`.

### Multiple monitors

Nothing to configure. A background daemon, `sway-output-profiles`, remembers **one layout per set of connected displays**:

- Connect a monitor it has not seen before → a profile is created from whatever sway does by default.
- Rearrange with `wdisplays` (**Super+Shift+d**, or any `swaymsg output …`) → the change is saved into that set's profile a couple of seconds later.
- Connect that same monitor again → the saved layout is restored automatically.

Profiles live in `~/.config/sway-output-profiles/profiles/`, one file per set, named `<count>-<hash>.conf`. They are plain sway `output` commands and safe to hand-edit — the header comment lists which displays the file is for:

```
# sway-output-profiles — generated. Edit freely; it is rewritten when
# you change this layout. Matched by the exact set of connected outputs.
#
#   DP-3   Dell Inc. DELL U2720Q ABC123
#   eDP-1  LG Display 0x0000 Unknown

output "Dell Inc. DELL U2720Q ABC123" enable mode 3840x2160@59.951Hz position 0 0 scale 1.5 transform normal
output "LG Display 0x0000 Unknown" enable mode 1920x1200@60.003Hz position 2560 360 scale 1 transform normal
```

Delete a file to forget that layout; it will be recreated from scratch next time those displays are connected. To pin a layout permanently, put the `output` lines in `~/.config/sway/config` instead — those win, and the daemon will keep recording the result.

#### Lost a display

**Super+Ctrl+d turns every connected display back on.** Use it any time a screen is missing
and you are not sure why — it is safe to press at any point, and works even with nothing on
screen at all.

A layout can legitimately disable a display (a docked laptop with the lid screen off, say),
and that gets remembered like any other setting. `wdisplays` lists disabled displays
alongside the active ones, each with an **Enabled** checkbox, so you can turn one back on
there too.

Super+Ctrl+d is deliberately blunt: it enables everything and does nothing else. If a
display was off on purpose, switch it back off in `wdisplays` afterwards and that will be
saved again. It exists because with *every* display disabled nothing is composited, so no
GUI can draw anything — a keybinding is the only way back. The daemon will never save an
all-off layout, so you should not be able to get there by accident.

Notes:

- Lid open and lid closed are remembered as *separate* layouts for the same set of displays, so the position and scale you set up with the lid open survive a day of working with it shut. That is also why the built-in display being off behind a closed lid is never mistaken for you switching it off on purpose.
- Pressing Super+Ctrl+d with the lid shut turns the built-in display back on and that gets saved, so the next lid close leaves it lit. Open and close the lid once to get back to normal.
- Two monitors of the same model *and* serial cannot be told apart by description, so those profiles key on connector name (`DP-1`, `DP-2`) instead. Connector names can shuffle across reboots or dock re-plugs; if that happens you get a fresh profile and one re-arrange.
- If `wdisplays` is open when you plug or unplug a monitor, its window resets to match the new hardware and an edit in progress may need redoing — normal behaviour for any output-management client, not specific to this setup.
- Daemon output goes to the sway log — `journalctl --user -b | grep sway-output-profiles` if something looks wrong.

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
| `Super+Shift+d` | Display layout (wdisplays) |
| `Super+Ctrl+d` | Turn every connected display back on |
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
| 11 min idle | Suspend — skipped while an external display is connected |
| Lid close, external display connected | Turn the built-in display off, nothing else |
| Lid close, no external display | Lock screen (and logind suspends) |
| Lid open | Turn the built-in display back on |
| Before sleep | Lock screen |

Closing the lid while docked does not lock, on the grounds that you are sitting in front of
the external screen. Idle still locks after 5 minutes either way. A display is "external"
when sway names it something other than `eDP-*`, `LVDS-*` or `DSI-*` — the same rule
systemd-logind uses.

## Adding a theme

Copy an existing directory under `themes/`, adjust the colours in all five files, then add a menu entry and a `case` branch to the theme-selection block in `setup-sway.sh`.
