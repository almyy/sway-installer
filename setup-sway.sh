#!/usr/bin/env bash
# setup-sway.sh — minimal sway install and configuration for Ubuntu 26.04+
# Run as your normal user (not root). Uses sudo internally where needed.
#
# Usage: ./setup-sway.sh [--dry-run]
#   --dry-run   Show what would be done without making any changes.
set -euo pipefail

# ─── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[info]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[ok]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[warn]${RESET}  $*"; }
dry()     { echo -e "${YELLOW}[dry-run]${RESET} $*"; }
die()     { echo -e "${RED}[error]${RESET} $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}▸ $*${RESET}"; }

# ─── Dry-run flag ─────────────────────────────────────────────────────────────
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) die "Unknown argument: $arg. Usage: $0 [--dry-run]" ;;
  esac
done

# Wrappers — in dry-run mode, print instead of executing
run()      { if $DRY_RUN; then dry "would run: $*"; else "$@"; fi; }
run_sudo() { if $DRY_RUN; then dry "would run: sudo $*"; else sudo "$@"; fi; }

if $DRY_RUN; then
  echo ""
  echo -e "${YELLOW}${BOLD}  Dry-run mode — no changes will be made.${RESET}"
fi

# ─── Guards ───────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] && die "Do not run this script as root. It will use sudo when needed."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/config"
THEMES_DIR="$SCRIPT_DIR/themes"
CONFIG_DST="$HOME/.config"

[[ -d "$CONFIG_SRC" ]]  || die "config/ directory not found (expected: $CONFIG_SRC)"
[[ -d "$THEMES_DIR" ]]  || die "themes/ directory not found (expected: $THEMES_DIR)"

# ─── 1. Packages ──────────────────────────────────────────────────────────────
section "Installing packages"

PACKAGES=(
  sway
  swaybg
  swayidle
  swaylock
  waybar
  wofi
  foot
  mako-notifier
  grimshot
  wl-clipboard
  xdg-desktop-portal-wlr
  fonts-jetbrains-mono
  network-manager-gnome
  blueman
  swappy
  nwg-bar
  gnome-keyring
  libpam-gnome-keyring
)

MISSING=()
for pkg in "${PACKAGES[@]}"; do
  dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed" || MISSING+=("$pkg")
done

if [[ ${#MISSING[@]} -eq 0 ]]; then
  ok "All packages already installed."
else
  info "Installing: ${MISSING[*]}"
  run_sudo apt-get update -qq
  run_sudo apt-get install -y "${MISSING[@]}"
  $DRY_RUN || ok "Packages installed."
fi

# ─── 2. Theme selection ───────────────────────────────────────────────────────
section "Choose a theme"

echo ""
echo -e "  ${BOLD}1)${RESET} Nord            — dark blue-grey ${CYAN}(default)${RESET}"
echo -e "  ${BOLD}2)${RESET} Gruvbox         — warm dark, earthy amber"
echo -e "  ${BOLD}3)${RESET} Catppuccin      — pastel dark, soft purple"
echo -e "  ${BOLD}4)${RESET} Solarized Light — classic light theme"
echo ""

THEME_DIR=""
while true; do
  read -rp "  Enter choice [1]: " choice
  choice="${choice:-1}"
  case "$choice" in
    1) THEME_DIR="$THEMES_DIR/nord";             break ;;
    2) THEME_DIR="$THEMES_DIR/gruvbox";          break ;;
    3) THEME_DIR="$THEMES_DIR/catppuccin";       break ;;
    4) THEME_DIR="$THEMES_DIR/solarized-light";  break ;;
    *) warn "Invalid choice — enter 1, 2, 3 or 4." ;;
  esac
done

# Source theme variables
# shellcheck source=/dev/null
source "$THEME_DIR/sway-theme.conf"
ok "Theme selected: $THEME_NAME"

# ─── 3. Gap size selection ────────────────────────────────────────────────────
section "Choose gap size"

echo ""
echo -e "  ${BOLD}1)${RESET} None   — no gaps or borders"
echo -e "  ${BOLD}2)${RESET} Small  — 4px inner, 2px outer"
echo -e "  ${BOLD}3)${RESET} Medium — 8px inner, 4px outer ${CYAN}(default)${RESET}"
echo -e "  ${BOLD}4)${RESET} Large  — 16px inner, 8px outer"
echo ""

INNER_GAP=8
OUTER_GAP=4
NO_BORDERS=false

while true; do
  read -rp "  Enter choice [3]: " choice
  choice="${choice:-3}"
  case "$choice" in
    1) INNER_GAP=0;  OUTER_GAP=0;  NO_BORDERS=true;  break ;;
    2) INNER_GAP=4;  OUTER_GAP=2;  NO_BORDERS=false; break ;;
    3) INNER_GAP=8;  OUTER_GAP=4;  NO_BORDERS=false; break ;;
    4) INNER_GAP=16; OUTER_GAP=8;  NO_BORDERS=false; break ;;
    *) warn "Invalid choice — enter 1, 2, 3 or 4." ;;
  esac
done

ok "Gap size: inner ${INNER_GAP}px, outer ${OUTER_GAP}px$(${NO_BORDERS} && echo ', borders disabled')"

# ─── 3. Install configs ───────────────────────────────────────────────────────
section "Installing config files"

# Back up a file if it exists and no .bak is present yet, then copy the new one
install_config() {
  local src="$1"
  local dst="$2"

  if $DRY_RUN; then
    dry "would install: $src → $dst"
    [[ -e "$dst" && ! -e "${dst}.bak" ]] && dry "would backup: $dst → ${dst}.bak"
    return
  fi

  mkdir -p "$(dirname "$dst")"

  if [[ -e "$dst" && ! -e "${dst}.bak" ]]; then
    mv "$dst" "${dst}.bak"
    warn "Backed up: $dst → ${dst}.bak"
  elif [[ -e "$dst" && -e "${dst}.bak" ]]; then
    warn "Skipping backup of $dst — ${dst}.bak already exists"
  fi

  cp "$src" "$dst"
  ok "Installed: $dst"
}

# sway/config — install from config/ then patch theme colours in place
install_config "$CONFIG_SRC/sway/config" "$CONFIG_DST/sway/config"

# Patch background colour
run sed -i "s|^output \* bg #[0-9a-fA-F]\{6\} solid_color|output * bg ${BG_COLOR} solid_color|" \
  "$CONFIG_DST/sway/config"

# Patch locker colour
run sed -i "s|swaylock -f -c [0-9a-fA-F]\{6\}|swaylock -f -c ${LOCKER_COLOR}|" \
  "$CONFIG_DST/sway/config"

# Patch client colour block — replace the 4 client.* lines
run sed -i \
  "/^client\.focused /c\\client.focused          ${CLIENT_FOCUSED}" \
  "$CONFIG_DST/sway/config"
run sed -i \
  "/^client\.focused_inactive /c\\client.focused_inactive ${CLIENT_FOCUSED_INACTIVE}" \
  "$CONFIG_DST/sway/config"
run sed -i \
  "/^client\.unfocused /c\\client.unfocused        ${CLIENT_UNFOCUSED}" \
  "$CONFIG_DST/sway/config"
run sed -i \
  "/^client\.urgent /c\\client.urgent           ${CLIENT_URGENT}" \
  "$CONFIG_DST/sway/config"

$DRY_RUN || ok "Patched theme colours into sway/config"

# Patch gap sizes
run sed -i "s/^gaps inner .*/gaps inner ${INNER_GAP}/" "$CONFIG_DST/sway/config"
run sed -i "s/^gaps outer .*/gaps outer ${OUTER_GAP}/" "$CONFIG_DST/sway/config"

# Disable borders if no gaps selected
if $NO_BORDERS; then
  run sed -i "s/^default_border .*/default_border none/"                   "$CONFIG_DST/sway/config"
  run sed -i "s/^default_floating_border .*/default_floating_border none/" "$CONFIG_DST/sway/config"
fi

$DRY_RUN || ok "Patched gaps into sway/config"

# Non-themed config files
install_config "$CONFIG_SRC/waybar/config"     "$CONFIG_DST/waybar/config"
install_config "$CONFIG_SRC/nwg-bar/bar.json"  "$CONFIG_DST/nwg-bar/bar.json"

# Themed config files
install_config "$THEME_DIR/waybar/style.css"   "$CONFIG_DST/waybar/style.css"
install_config "$THEME_DIR/wofi/style.css"     "$CONFIG_DST/wofi/style.css"
install_config "$THEME_DIR/foot/foot.ini"      "$CONFIG_DST/foot/foot.ini"
install_config "$THEME_DIR/mako/config"        "$CONFIG_DST/mako/config"

# ─── 4. PAM — gnome-keyring auto-unlock ───────────────────────────────────────
section "Configuring PAM for gnome-keyring auto-unlock"

patch_pam() {
  local pamfile="/etc/pam.d/gdm-password"

  if [[ ! -f "$pamfile" ]]; then
    warn "PAM file not found, skipping: $pamfile"
    return
  fi

  if $DRY_RUN; then
    dry "would patch PAM: $pamfile"
    dry "would add: auth     optional  pam_gnome_keyring.so"
    dry "would add: session  optional  pam_gnome_keyring.so auto_start"
    return
  fi

  # Backup
  if [[ ! -f "${pamfile}.bak" ]]; then
    sudo cp "$pamfile" "${pamfile}.bak"
    warn "Backed up: $pamfile → ${pamfile}.bak"
  fi

  # Patch auth line if not already present
  if ! sudo grep -q "^auth.*pam_gnome_keyring" "$pamfile"; then
    sudo sed -i '/^auth.*pam_unix\.so/a auth     optional  pam_gnome_keyring.so' "$pamfile"
  fi

  # Patch session line if not already present
  if ! sudo grep -q "^session.*pam_gnome_keyring" "$pamfile"; then
    sudo sed -i '/^session.*pam_unix\.so/a session  optional  pam_gnome_keyring.so auto_start' "$pamfile"
  fi

  # Verify both lines are present after patching
  if sudo grep -q "^auth.*pam_gnome_keyring" "$pamfile" && \
     sudo grep -q "^session.*pam_gnome_keyring" "$pamfile"; then
    ok "PAM keyring integration active: $pamfile"
  else
    warn "PAM patch may be incomplete — verify $pamfile manually"
  fi
}

patch_pam

# ─── 5. Summary ───────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}${BOLD}  Setup complete!${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  Theme installed: ${BOLD}${THEME_NAME}${RESET}"
echo ""
echo -e "  ${BOLD}Next steps:${RESET}"
echo ""
echo -e "  1. ${CYAN}Log out${RESET} and select ${BOLD}Sway${RESET} at the GDM login screen."
echo ""
echo -e "  2. ${CYAN}Set a wallpaper${RESET} (once logged in):"
echo -e "       swaymsg \"output * bg /path/to/image fill\""
echo -e "     Or edit ~/.config/sway/config:"
echo -e "       output * bg /path/to/image fill"
echo ""
echo -e "  3. ${CYAN}Configure monitors${RESET} — edit ~/.config/sway/config and"
echo -e "     uncomment / adapt the output section. Run:"
echo -e "       swaymsg -t get_outputs"
echo -e "     to list your display names."
echo ""
echo -e "  4. ${CYAN}Brightness keys${RESET} need brightnessctl:"
echo -e "       sudo apt install brightnessctl"
echo -e "       sudo usermod -aG video \$USER  # then log out/in"
echo ""
echo -e "  5. ${CYAN}Screen sharing${RESET} (e.g. Firefox/Chrome) works via"
echo -e "     xdg-desktop-portal-wlr. If not, log out and back in."
echo ""
echo -e "  ${BOLD}Key bindings quick reference:${RESET}"
echo -e "    Super+Enter         terminal"
echo -e "    Super+d             launcher (wofi)"
echo -e "    Super+l             lock screen"
echo -e "    Super+Shift+p       power menu (shutdown/reboot/logout)"
echo -e "    Super+Shift+e       exit sway"
echo -e "    Super+Shift+r       reload config"
echo -e "    Super+r             resize mode"
echo -e "    Super+arrows        focus"
echo -e "    Super+Shift+arrows  move window"
echo -e "    Super+1-9           switch workspace"
echo -e "    Print               screenshot area → swappy"
echo ""
