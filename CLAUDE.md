# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single-script installer that sets up sway on Ubuntu 26.04+: `setup-sway.sh` installs apt packages, prompts for theme/gaps/bar-position, copies config files into `~/.config/`, and patches `/etc/pam.d/gdm-password` for gnome-keyring auto-unlock.

There is no build system, no test suite, and no dependencies beyond bash + apt.

## Commands

```bash
./setup-sway.sh --dry-run    # print every action without changing anything
./setup-sway.sh              # real install
bash -n setup-sway.sh        # syntax check
jq . config/waybar/config config/nwg-bar/bar.json   # validate JSON

# validate sway config syntax
env -u WAYLAND_DISPLAY WLR_BACKENDS=headless sway -C -c config/sway/config
```

`sway -C` still initialises a backend before parsing, so a bare `sway -C` fails with "Unable to create backend" when `WAYLAND_DISPLAY` is set but unreachable (the usual case in a sandboxed shell). The `env -u … WLR_BACKENDS=headless` prefix is what makes it actually reach config parsing; it prints harmless `/dev/dri/renderD128: Permission denied` noise, and silence after that means the config is valid.

`--dry-run` is the primary verification tool, but note its limits: it still runs the interactive prompts and still `source`s the theme file, while `run`/`run_sudo` wrap the `sed` patches — so a patch whose anchor no longer matches will *silently* look fine in dry-run. To actually verify patching, run the installer for real and inspect `~/.config/sway/config`.

`shellcheck` is not installed here; install it before relying on it.

## Architecture

Two source trees feed `~/.config/`:

- **`config/`** — theme-agnostic sources: `sway/config`, `waybar/config`, `nwg-bar/bar.json`. One copy, shared by all themes.
- **`themes/<name>/`** — per-theme variants: `waybar/style.css`, `wofi/style.css`, `foot/foot.ini`, `mako/config` (copied verbatim), plus `sway-theme.conf`.

`sway-theme.conf` is not a config file — it's a shell fragment `source`d by the installer, exporting `THEME_NAME`, `BG_COLOR`, `LOCKER_COLOR`, and the four `CLIENT_*` colour tuples (`border bg text indicator child_border`).

### The sed-patching contract

`config/sway/config` is a complete, working Nord-themed config that the installer **mutates in place after copying** to `~/.config/`. Each user choice becomes a `sed` expression anchored on an exact line shape in the source file:

| Choice | Anchor in source | Patched by |
|---|---|---|
| Theme background | `output * bg #1a1a2e solid_color` | `BG_COLOR` |
| Lock screen colour | `swaylock -f -c 1a1a2e` | `LOCKER_COLOR` |
| Window colours | lines starting `client.focused `, `client.focused_inactive `, `client.unfocused `, `client.urgent ` | `CLIENT_*` |
| Gaps | lines starting `gaps inner `, `gaps outer ` | `INNER_GAP`, `OUTER_GAP` |
| No-gaps variant | `default_border `, `default_floating_border ` | set to `none` |
| Bar position | `"position": "…"` in `config/waybar/config` | `BAR_POSITION` |

**When editing these lines in `config/`, keep the anchor shape intact** — the same 6-hex-digit format, the same leading token, no added indentation. A reformatted line makes the corresponding `sed` a no-op and the user silently gets the committed Nord/default value instead of their choice. Conversely, adding a new option means adding both the menu block and a matching `sed`.

`config/nwg-bar/bar.json` carries a `swaylock -f -c 1a1a2e` line patched by the same `LOCKER_COLOR` regex as `sway/config`, so the power-menu lock screen matches the chosen theme. Keep the 6-hex-digit shape if you edit it.

### Adding a theme

1. `themes/<name>/` with all five files (copy an existing theme as the starting point — the four app files are full replacements, not overlays).
2. Add a menu line and a `case` branch in the theme-selection block of `setup-sway.sh`, and widen the "enter 1, 2, 3 or 4" validation message.

### Install semantics

`install_config` backs up an existing destination to `<file>.bak` only if no `.bak` exists yet; on re-runs it warns and overwrites without a second backup. So the `.bak` files always hold the user's *pre-installer* config, and running the script repeatedly is safe for the user's original files.

PAM patching is idempotent (greps for `pam_gnome_keyring` before inserting) and backs up to `gdm-password.bak`.

### Monitor layout

`config/sway/config` ends its Output section with `include outputs`, which picks up the file `nwg-displays` writes to `~/.config/sway/outputs`. sway ignores a missing include target without complaint, so this is inert until the user runs `nwg-displays`. There is no keybinding for it.

## Keeping docs honest

`README.md` documents user-facing behaviour — package list, the three install prompts, keybindings, idle timings — all of which live in `setup-sway.sh` and `config/sway/config`. Those two files are the source of truth; when changing a binding, prompt, or package, update the README table in the same commit. It has drifted before.
