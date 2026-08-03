#!/usr/bin/env bash
# setup-sway.sh — minimal sway install and configuration for Ubuntu 26.04+
# Run as your normal user (not root). Uses sudo internally where needed.
set -euo pipefail

# ─── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[info]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[ok]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[warn]${RESET}  $*"; }
die()     { echo -e "${RED}[error]${RESET} $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}▸ $*${RESET}"; }

# ─── Guards ───────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] && die "Do not run this script as root. It will use sudo when needed."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/config"
CONFIG_DST="$HOME/.config"

[[ -d "$CONFIG_SRC" ]] || die "config/ directory not found next to this script (expected: $CONFIG_SRC)"

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
)

MISSING=()
for pkg in "${PACKAGES[@]}"; do
  dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed" || MISSING+=("$pkg")
done

if [[ ${#MISSING[@]} -eq 0 ]]; then
  ok "All packages already installed."
else
  info "Installing: ${MISSING[*]}"
  sudo apt-get update -qq
  sudo apt-get install -y "${MISSING[@]}"
  ok "Packages installed."
fi

# ─── 2. Install configs ───────────────────────────────────────────────────────
section "Installing config files"

# Back up a file if it exists and no .bak is present yet, then copy the new one
install_config() {
  local src="$1"
  local dst="$2"

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

install_config "$CONFIG_SRC/sway/config"       "$CONFIG_DST/sway/config"
install_config "$CONFIG_SRC/waybar/config"     "$CONFIG_DST/waybar/config"
install_config "$CONFIG_SRC/waybar/style.css"  "$CONFIG_DST/waybar/style.css"
install_config "$CONFIG_SRC/wofi/style.css"    "$CONFIG_DST/wofi/style.css"
install_config "$CONFIG_SRC/foot/foot.ini"     "$CONFIG_DST/foot/foot.ini"
install_config "$CONFIG_SRC/mako/config"       "$CONFIG_DST/mako/config"

# ─── 3. Summary ───────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}${BOLD}  Setup complete!${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
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
echo -e "    Super+Enter       terminal"
echo -e "    Super+d           launcher (wofi)"
echo -e "    Super+l           lock screen"
echo -e "    Super+Shift+e     exit sway"
echo -e "    Super+Shift+r     reload config"
echo -e "    Super+r           resize mode"
echo -e "    Super+hjkl/arrows focus"
echo -e "    Super+Shift+hjkl  move window"
echo -e "    Super+1-9         switch workspace"
echo -e "    Print             screenshot (area)"
echo ""
