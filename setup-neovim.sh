#!/bin/bash
set -euo pipefail

# ==============================================================================
# Neovim + LazyVim C/C++ Development Environment Setup
# ==============================================================================

NVIM_INSTALL_DIR="/opt/nvim"
NVIM_CONFIG_DIR="$HOME/.config/nvim"
BASHRC="$HOME/.bashrc"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${GREEN}==>${NC} $1"; }

# ==============================================================================
# Preflight checks
# ==============================================================================

section "Running preflight checks..."

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
  error "This script is intended for Linux (x86_64) only."
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
  error "This script only supports x86_64 architecture."
fi

for cmd in curl git sudo; do
  if ! command -v "$cmd" &>/dev/null; then
    error "'$cmd' is required but not installed. Please install it and re-run."
  fi
done

info "All preflight checks passed."

# ==============================================================================
# Install Neovim
# ==============================================================================

section "Installing Neovim..."

if command -v nvim &>/dev/null; then
  warn "Neovim is already installed at $(which nvim). Skipping installation."
else
  sudo mkdir -p "$NVIM_INSTALL_DIR"
  curl -L https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz \
    | sudo tar -C "$NVIM_INSTALL_DIR" -xzf - --strip-components=1

  PATH_EXPORT='export PATH="$PATH:/opt/nvim/bin"'
  if ! grep -qF "$PATH_EXPORT" "$BASHRC"; then
    echo "$PATH_EXPORT" >> "$BASHRC"
    info "Added /opt/nvim/bin to PATH in $BASHRC"
  else
    warn "PATH entry already exists in $BASHRC. Skipping."
  fi

  export PATH="$PATH:/opt/nvim/bin"
  info "Neovim installed successfully: $(nvim --version | head -1)"
fi

# ==============================================================================
# Install LazyVim
# ==============================================================================

section "Installing LazyVim..."

# Backup existing config if present
for dir in "$NVIM_CONFIG_DIR" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
  if [[ -d "$dir" && ! -d "${dir}.bak" ]]; then
    warn "Backing up existing $dir to ${dir}.bak"
    mv "$dir" "${dir}.bak"
  elif [[ -d "$dir" && -d "${dir}.bak" ]]; then
    warn "$dir and ${dir}.bak both exist. Leaving $dir as-is."
  fi
done

if [[ ! -d "$NVIM_CONFIG_DIR/.git" ]]; then
  git clone https://github.com/LazyVim/starter "$NVIM_CONFIG_DIR"
  rm -rf "$NVIM_CONFIG_DIR/.git"
  info "LazyVim starter config cloned."
else
  warn "LazyVim config already exists at $NVIM_CONFIG_DIR. Skipping clone."
fi

# ==============================================================================
# Install Monokai Pro theme plugin
# ==============================================================================

section "Installing Monokai Pro theme..."

mkdir -p "$NVIM_CONFIG_DIR/lua/plugins"

cat > "$NVIM_CONFIG_DIR/lua/plugins/monokai.lua" << 'EOF'
return {
  {
    "loctvl842/monokai-pro.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("monokai-pro").setup({
        transparent_background = false,
        terminal_colors = true,
        devicons = true,
        styles = {
          comment = { italic = true },
          keyword = { italic = true },
          type = { italic = true },
          storageclass = { italic = true },
          structure = { italic = true },
          parameter = { italic = true },
          annotation = { italic = true },
          tag_attribute = { italic = true },
        },
        filter = "pro", -- classic | octagon | pro | machine | ristretto | spectrum
        day_night = {
          enable = false,
          day_filter = "pro",
          night_filter = "spectrum",
        },
        inc_search = "background", -- underline | background
        background_clear = {
          "toggleterm",
          "telescope",
          "renamer",
          "notify",
        },
        plugins = {
          bufferline = {
            underline_selected = false,
            underline_visible = false,
            underline_fill = false,
            bold = true,
          },
          indent_blankline = {
            context_highlight = "default", -- default | pro
            context_start_underline = false,
          },
        },
        override = function(scheme) return {} end,
        override_palette = function(filter) return {} end,
        override_scheme = function(scheme, palette, colors) return {} end,
      })
      vim.cmd.colorscheme("monokai-pro")
    end,
  },
}
EOF

info "Monokai Pro plugin config written."

# ==============================================================================
# Fix autocomplete: Tab to accept instead of Enter
# ==============================================================================

section "Configuring blink.cmp (Tab to accept)..."

cat > "$NVIM_CONFIG_DIR/lua/plugins/blink.lua" << 'EOF'
return {
  "saghen/blink.cmp",
  opts = {
    keymap = {
      ["<CR>"] = {},
      ["<Tab>"] = { "accept", "fallback" },
    },
  },
}
EOF

info "blink.cmp config written."

# ==============================================================================
# Configure LazyExtras for C/C++ development
# ==============================================================================

section "Configuring LazyExtras plugins..."

EXTRAS_FILE="$NVIM_CONFIG_DIR/lua/config/lazy.lua"

# LazyVim supports extras via the extras field in lazy.lua or a separate extras.lua
# The cleanest approach that doesn't break the starter template is writing extras.lua
EXTRAS_CONFIG="$NVIM_CONFIG_DIR/lua/plugins/extras.lua"

cat > "$EXTRAS_CONFIG" << 'EOF'
-- LazyVim extras - equivalent to selecting these in :LazyExtras
return {
  { import = "lazyvim.plugins.extras.lang.clangd" },
  { import = "lazyvim.plugins.extras.lang.cmake" },
  { import = "lazyvim.plugins.extras.lang.git" },
  { import = "lazyvim.plugins.extras.lang.json" },
  { import = "lazyvim.plugins.extras.lang.markdown" },
  { import = "lazyvim.plugins.extras.lang.python" },
}
EOF

info "LazyExtras plugin imports written."

# ==============================================================================
# Done
# ==============================================================================

echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN} Setup complete!${NC}"
echo -e "${GREEN}================================================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Reload your shell:    source ~/.bashrc"
echo "  2. Launch Neovim:        nvim"
echo "  3. Wait for plugins to finish installing (Lazy will run automatically)"
echo "  4. For C/C++ projects, make sure compile_commands.json is present:"
echo "       - CMake:  cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON <src_dir>"
echo "       - Make:   bear -- make"
echo "       - SCons:  use env.CompilationDatabase('compile_commands.json')"
echo ""
echo "  Tip: run :checkhealth in Neovim to diagnose any missing dependencies."
echo ""
