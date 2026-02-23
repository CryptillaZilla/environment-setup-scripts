#!/bin/bash

set -e

# ─────────────────────────────────────────
#  Alacritty Setup Script
# ─────────────────────────────────────────

FONT_DIR="$HOME/.local/share/fonts/JetBrainsMono"
CONFIG_DIR="$HOME/.config/alacritty"
CONFIG_FILE="$CONFIG_DIR/alacritty.toml"
FONT_SIZE=14
FONT_FAMILY="JetBrainsMono Nerd Font"

THEMES=(
  "rose-pine|https://raw.githubusercontent.com/rose-pine/alacritty/refs/heads/main/dist/rose-pine.toml"
  "rose-pine-moon|https://raw.githubusercontent.com/rose-pine/alacritty/refs/heads/main/dist/rose-pine-moon.toml"
  "rose-pine-dawn|https://raw.githubusercontent.com/rose-pine/alacritty/refs/heads/main/dist/rose-pine-dawn.toml"
  "tokyo-night|https://raw.githubusercontent.com/zatchheems/tokyo-night-alacritty-theme/refs/heads/main/tokyo-night.toml"
  "tokyo-night-storm|https://raw.githubusercontent.com/zatchheems/tokyo-night-alacritty-theme/refs/heads/main/tokyo-night-storm.toml"
)

# ─── Helpers ──────────────────────────────

info() { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() {
  echo -e "\033[1;31m[ERROR]\033[0m $*" >&2
  exit 1
}

check_deps() {
  for cmd in wget unzip fc-cache apt; do
    command -v "$cmd" &>/dev/null || error "Required command '$cmd' not found."
  done
}

# ─── Steps ────────────────────────────────

install_alacritty() {
  if command -v alacritty &>/dev/null; then
    warn "Alacritty already installed — skipping."
  else
    info "Installing Alacritty..."
    sudo apt update -qq && sudo apt install -y alacritty
    success "Alacritty installed."
  fi
}

install_font() {
  if fc-list | grep -qi "JetBrainsMono Nerd Font"; then
    warn "JetBrainsMono Nerd Font already installed — skipping."
    return
  fi

  info "Installing JetBrainsMono Nerd Font..."
  mkdir -p "$FONT_DIR"

  local tmp
  tmp=$(mktemp -d)
  wget -q --show-progress -O "$tmp/JetBrainsMono.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip"

  unzip -q "$tmp/JetBrainsMono.zip" -d "$FONT_DIR"
  rm -rf "$tmp"

  fc-cache -fv &>/dev/null
  success "Font installed and cache refreshed."
}

download_themes() {
  info "Creating config directory at $CONFIG_DIR..."
  mkdir -p "$CONFIG_DIR"

  info "Downloading themes..."
  for entry in "${THEMES[@]}"; do
    local name url
    name="${entry%%|*}"
    url="${entry##*|}"

    if [[ -f "$CONFIG_DIR/${name}.toml" ]]; then
      warn "Theme '$name' already exists — skipping."
    else
      wget -q -O "$CONFIG_DIR/${name}.toml" "$url"
      success "Downloaded: $name"
    fi
  done
}

pick_theme() {
  echo ""
  echo "Available themes:"
  local i=1
  local names=()
  for entry in "${THEMES[@]}"; do
    local name="${entry%%|*}"
    names+=("$name")
    echo "  $i) $name"
    ((i++))
  done

  local choice
  while true; do
    read -rp "Pick a theme [1-${#names[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#names[@]})); then
      SELECTED_THEME="${names[$((choice - 1))]}"
      break
    fi
    warn "Invalid choice. Please enter a number between 1 and ${#names[@]}."
  done
  success "Selected theme: $SELECTED_THEME"
}

write_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    warn "Config file already exists at $CONFIG_FILE"
    read -rp "Overwrite? [y/N]: " overwrite
    [[ "$overwrite" =~ ^[Yy]$ ]] || {
      info "Skipping config write."
      return
    }
  fi

  info "Writing $CONFIG_FILE..."
  cat >"$CONFIG_FILE" <<TOML
import = ["$CONFIG_DIR/$SELECTED_THEME.toml"]

[font]
size = $FONT_SIZE

[font.normal]
family = "$FONT_FAMILY"
TOML
  success "Config written."
}

# ─── Main ─────────────────────────────────

main() {
  echo ""
  echo "╔══════════════════════════════════╗"
  echo "║      Alacritty Setup Script      ║"
  echo "╚══════════════════════════════════╝"
  echo ""

  check_deps
  install_alacritty
  install_font
  download_themes
  pick_theme
  write_config

  echo ""
  success "All done! Launch Alacritty to see your new setup."
  echo ""
  echo "  To switch themes later, update the import line in:"
  echo "  $CONFIG_FILE"
  echo ""
}

main
