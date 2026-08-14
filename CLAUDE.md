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

A third tree, **`bin/`**, feeds `~/.local/bin/` via `install_bin` (cp + `chmod 0755`, no `.bak`). It holds `sway-output-profiles` and `sway-docked`.

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

### Monitor layout — `bin/sway-output-profiles`

Layouts are remembered per *set of connected outputs*. The daemon subscribes to sway's `output` events and keys everything off a **fingerprint**: the sorted `make model serial` descriptions of the connected outputs. Files live in `~/.config/sway-output-profiles/profiles/<count>-<sha256[0:12]>.conf` and contain plain sway `output` command lines.

The core rule is that **fingerprint changed → apply or seed; fingerprint unchanged → save**. Seeding never applies and applying never seeds, which is what keeps the two directions from fighting.

Nothing here is arbitrary — each of these guards exists because removing it causes silent data loss. Do not "simplify" them away:

- **`exec_always`, not `exec`** (`config/sway/config` Autostart). `swaymsg reload` rebuilds output config from the config file alone, resetting the layout. The second invocation takes the flock, fails, and `SIGUSR1`s the incumbent to re-apply. Without this, `$mod+Shift+r` both wipes the layout *and* looks like a user edit, so the reset gets saved over the real profile.
- **`SAVE_DELAY` + `suppress_until`.** A save is only committed after the state holds still for ~2s and outside a 3s window after we apply something. The delay is what lets the reload `SIGUSR1` land before the reset is mistaken for an edit.
- **The `snapshot_usable` power guard.** swayidle runs `output * dpms off` at 600s. A powered-off output reports `power`/`dpms` false, and on DRM its `current_mode` collapses to `0x0@0`. Both are checked, because which one you see depends on the backend. Without this, one idle timeout rewrites the profile as `mode 0x0@0Hz`. A skipped cycle must **not** update `last_fp`, or a hotplug during blanking is swallowed.
- **`mode` omits `@…Hz` when refresh is 0.** Virtual and headless outputs report `refresh: 0`, and `mode 1920x1080@0Hz` is rejected on apply.
- **`JQ_REAL` filters `non_desktop`.** `get_outputs` reports VR/DRM-lease headsets, which are not part of a desktop layout. It does *not* filter sway's fallback output by name — `ipc-server.c` already skips it, and a name filter would discard real outputs on a headless session. When every output disappears the list is simply empty, which `snapshot_usable`'s length check handles.
- **`position X Y`, never `position X,Y`.** sway's command parser splits arguments on `;` and `,`, so the comma form silently breaks over IPC (it works in a config *file*, which is why it looks correct).
- **No timestamp in the generated header.** Profile text must be byte-identical for an unchanged layout or the "did it change?" comparison always says yes and the daemon rewrites forever.
- **`adaptive_sync on` only when already enabled, never `off`.** sway applies the output config atomically; one rejected directive drops the whole apply.
- **Duplicate-description fallback.** Identical panels report identical `make model serial`, and one criteria matching two outputs stacks them. When a description repeats, the profile keys on connector names *and* the names join the fingerprint — so a name shuffle yields a new profile rather than a wrong-monitor apply.
- **`snapshot_usable` requires at least one *active* output.** Every other clause in it reads "(inactive) or (sane)", so with all outputs inactive they are vacuously true and an all-disabled state looks like a good snapshot. Without this clause the daemon saves a profile of pure `disable` lines and reapplies it at every login. That is unrecoverable from inside the session: sway's `root->fallback_output` is deliberately given no scene output (`handle_new_output()` says so explicitly), is never committed, and is not advertised as a wlr-output-management head — so with zero enabled outputs nothing is composited and no Wayland client can draw. This clause is why `$mod+Ctrl+d` should never be needed.
- **`apply_profile` refuses a profile that enables nothing.** Belt to the above's braces, since versions before that guard could have written one to disk. A bad file stays but is inert, and the next real change overwrites it.
- **Lid state is part of the fingerprint.** `bin/sway-docked` disables the built-in panel when the lid shuts with an external display connected, and that does *not* change the set of connected outputs — the panel is still in `get_outputs`, merely `active: false`. Without the `|lid=closed` suffix the daemon reads it as a geometry edit and saves `disable` into the docked profile, so the next dock with the lid open blanks the laptop screen. With it, docked-lid-shut and docked-lid-open are two profiles and every other rule applies to each unchanged: closing or opening the lid is an ordinary fingerprint change that `reconcile` handles, and rearranging externals with the lid shut cannot touch the lid-open layout. `sway-docked` writes `$XDG_RUNTIME_DIR/sway-output-profiles.lid` *before* the `swaymsg` that wakes the daemon, so the daemon never pairs new output state with a stale lid state. It is the authority on lid state, not `/proc/acpi/button/lid/*/state`, which lies on some laptops — and it writes `closed` only when it actually turned the panel off, so a lid close with nothing docked is invisible here.
- **Loop-breaker.** A backstop against a runaway rewrite: >`LOOP_MAX` writes for the *same* fingerprint inside `LOOP_WINDOW` freezes that profile until the outputs change. Counted per fingerprint and set deliberately high (12 per 30s) — an earlier global counter at 3 per 60s false-fired on three legitimate saves across two different layouts and silently dropped a real one. Every save from a human clicking Apply in a display GUI is genuine, so the threshold must sit far above human clicking speed.

`wdisplays` (`$mod+Shift+d`) is the GUI for *making* a change, which the daemon then captures. It replaced `nwg-displays` because it drives wlr-output-management directly, and that protocol advertises a head for every connected output including disabled ones — so a display a profile has disabled is still listed, with an `_Enabled` checkbox. nwg-displays' drag canvas is built from `i3.get_tree()`, which omits inactive outputs. (nwg-displays could *also* re-enable one, via an "Active:" checkbox row sourced from `get_outputs()`, but that row is built once at startup and never refreshed, and `main.py:583` does an unguarded `display_buttons[0].select()` that raises `IndexError` when nothing is active.)

wdisplays writes no config file of its own, which is now a feature: the daemon is the sole persistence layer, and the stale `~/.config/sway/outputs` that nwg-displays used to leave behind is gone.

Changes made over wlr-output-management reach the daemon identically to `swaymsg output` ones. Both converge on `apply_resolved_output_configs()` → `update_output_manager_config()` → `ipc_event_output()`, and each is the *sole* call site of the next, so the wlr `done` event and the sway IPC event are emitted from adjacent lines. There is no path that updates a GUI's view without also waking the daemon.

Do **not** try to suppress the daemon's applies while a display GUI is open. wdisplays already resets its own forms whenever a head is added or removed, so a hotplug discards an in-progress edit before the daemon acts; the daemon's added exposure is a sub-second window after that. Suppressing applies would break restore-on-dock, which is the entire feature.

Test the daemon's pure functions without a sway session by extracting the helpers and feeding synthetic `get_outputs` JSON — note this must run under **bash**, not the default zsh, because of `printf '%(%s)T'` and fractional `read -t`:

```bash
sed -n '1,/^# ─── Acting/p' bin/sway-output-profiles > /tmp/helpers.sh
bash -c 'source /tmp/helpers.sh; S=$(cat fixture.json); snapshot_usable "$S" && fingerprint "$S" "" && gen_profile "$S" "$(dupes_present "$S")"'
# fingerprint's second argument is lid state: "" or "closed". The two must differ,
# and each must be byte-stable across runs.
```

### Lid handling — `bin/sway-docked`

One helper holds every "does an external display change what we do?" decision, and its
exit status means **0 = docked / handled** in all three forms. That is what lets the sway
config express the policy as plain shell without duplicating anything:

```
bindswitch --reload --locked lid:on  exec $docked lid-close || $locker
bindswitch --reload --locked lid:off exec $docked lid-open
    timeout 660  "$docked || systemctl suspend" \
```

`exec` hands its whole line to `sh`, so `||` works — same reason the `grimshot … | swappy`
bindings do. Keeping the fallback in the config rather than inside `sway-docked` is
deliberate: `set $locker` stays the one place the lock command appears, so the installer's
`LOCKER_COLOR` sed keeps working and `sway-docked` needs no patching at install time.

- **logind is not involved.** `HandleLidSwitchDocked=ignore` is already the default and logind counts any connected non-`eDP`/`LVDS`/`DSI` DRM connector as docked, so it ignores the lid whenever a monitor is plugged in. The installer touches no logind config. The suspend that used to happen while docked came from swayidle's 660s timer, not from the lid.
- **`lid-open` only undoes a `lid-close` of ours** — it returns early unless the lid file says `closed`. A layout may legitimately disable the built-in display with the lid open, and `--reload` fires this binding on every `$mod+Shift+r`; without the guard, a reload would re-enable a display the user switched off in `wdisplays`.
- **Internal panels are matched by name** (`^(eDP|LVDS|DSI)-`), the same rule logind uses, and read from `get_outputs` rather than hardcoded.
- **Every failure path falls towards locking.** A failed or empty `get_outputs` yields an external count of 0, i.e. "not docked", i.e. lock.
- **`lid-open` issues a bare `output … enable`** and lets the resulting output event make the daemon apply the saved lid-open profile a moment later. Momentarily wrong geometry is the price of still getting a usable screen when no profile exists yet.

## Keeping docs honest

`README.md` documents user-facing behaviour — package list, the three install prompts, keybindings, idle timings, lid behaviour, monitor handling — all of which live in `setup-sway.sh`, `config/sway/config`, `bin/sway-output-profiles` and `bin/sway-docked`. Those files are the source of truth; when changing a binding, prompt, or package, update the README table in the same commit. It has drifted before. The installer's own summary block at the end of `setup-sway.sh` is a *third* copy of some of this and drifts most easily.
