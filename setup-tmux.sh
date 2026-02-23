#!/bin/bash

set -e

# ─────────────────────────────────────────────
# CONFIG — edit these before running
# ─────────────────────────────────────────────
REPO="$HOME/my-repo"
JOURNAL="$HOME/my-journals"
SHELL_RC="$HOME/.bashrc" # change to ~/.zshrc if using zsh
# ─────────────────────────────────────────────

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

log() { echo -e "${CYAN}==>${NC} $1"; }
ok() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }

# ─────────────────────────────────────────────
# 1. INSTALL TMUX
# ─────────────────────────────────────────────
log "Installing tmux..."
sudo apt update -qq
sudo apt install -y tmux
ok "tmux installed"

# ─────────────────────────────────────────────
# 2. INSTALL TMUXINATOR (optional — vanilla fallback if it fails)
# ─────────────────────────────────────────────
log "Attempting to install tmuxinator..."
TMUXINATOR_OK=false
if sudo apt install -y tmuxinator 2>/dev/null; then
  TMUXINATOR_OK=true
  ok "tmuxinator installed"
else
  warn "tmuxinator install failed — will set up vanilla startup script instead"
fi

# ─────────────────────────────────────────────
# 3. INSTALL TPM
# ─────────────────────────────────────────────
log "Installing TPM (tmux plugin manager)..."
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  ok "TPM cloned"
else
  ok "TPM already installed, skipping"
fi

# ─────────────────────────────────────────────
# 4. WRITE ~/.tmux.conf
# ─────────────────────────────────────────────
log "Writing ~/.tmux.conf..."
cat >"$HOME/.tmux.conf" <<'EOF'
## VIM-STYLE COPY MODE NAVIGATION

# Use vi-style keys for navigating and selection
set-window-option -g mode-keys vi

# 'v' to begin selection as in Vim
bind-key -T copy-mode-vi v send -X begin-selection

# 'y' to yank to system clipboard (requires xclip)
bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -selection clipboard -i"

## VIM-STYLE PANE NAVIGATION
# Using Prefix + vim-key to avoid conflicts with vim-tmux-navigator and ctrl+l

bind-key 'h' select-pane -L
bind-key 'j' select-pane -D
bind-key 'k' select-pane -U
bind-key 'l' select-pane -R

## NO CONFIRM ON CLOSE

bind-key & kill-window
bind-key x kill-pane

## NVIM

# Reduce escape time for nvim
set-option -sg escape-time 10

# Enable focus events for nvim
set-option -g focus-events on

# True color support
# Replace tmux-256color with output of `echo $TERM` if colors look wrong
set-option -a terminal-features 'tmux-256color:RGB'
set -g default-terminal "tmux-256color"

######################### PLUGINS — MUST BE AT BOTTOM

set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'janoamaral/tokyo-night-tmux'

# Optional: restore nvim sessions via resurrect
# (with LazyVim use its own restore feature instead — leave this commented)
# set -g @resurrect-strategy-nvim 'session'

# Initialize TPM (must be the very last line)
run '~/.tmux/plugins/tpm/tpm'
EOF
ok "~/.tmux.conf written"

# ─────────────────────────────────────────────
# 5. INSTALL XCLIP
# ─────────────────────────────────────────────
log "Installing xclip..."
sudo apt install -y xclip
ok "xclip installed"

# ─────────────────────────────────────────────
# 6. CREATE REPO AND JOURNAL DIRS IF MISSING
# ─────────────────────────────────────────────
log "Creating repo and journal directories if missing..."
mkdir -p "$REPO"
mkdir -p "$JOURNAL"
ok "Directories ready: $REPO, $JOURNAL"

# ─────────────────────────────────────────────
# 7. ALIAS HELPER
# ─────────────────────────────────────────────
add_alias() {
  local alias_line="$1"
  local alias_name
  alias_name=$(echo "$alias_line" | cut -d'=' -f1 | sed 's/alias //')
  if grep -q "alias $alias_name=" "$SHELL_RC" 2>/dev/null; then
    echo "   alias '$alias_name' already exists in $SHELL_RC, skipping"
  else
    echo "$alias_line" >>"$SHELL_RC"
    echo "   added: $alias_line"
  fi
}

# ─────────────────────────────────────────────
# 8. TMUXINATOR PATH OR VANILLA FALLBACK
# ─────────────────────────────────────────────
if [ "$TMUXINATOR_OK" = true ]; then
  log "Writing tmuxinator config..."
  mkdir -p "$HOME/.config/tmuxinator"
  cat >"$HOME/.config/tmuxinator/start-day.yml" <<EOF
name: dev

windows:
  - editor:
      root: "$REPO"
      panes:
        - nvim .
  - repo:
      root: "$REPO"
      layout: even-horizontal
      panes:
        -
        -
  - journal:
      root: "$JOURNAL"
      panes:
        -
  - scratch:
EOF
  ok "~/.config/tmuxinator/start-day.yml written"

  log "Adding startday alias (tmuxinator)..."
  add_alias "alias startday=\"tmuxinator start start-day\""
else
  log "Writing vanilla startup script as fallback..."
  cat >"$HOME/start-day.sh" <<EOF
#!/bin/bash

SESSION="dev"
REPO="$REPO"
JOURNAL="$JOURNAL"

# Attach if session already exists
tmux has-session -t \$SESSION 2>/dev/null && tmux attach -t \$SESSION && exit

tmux new-session -d -s \$SESSION -n "editor" -c \$REPO

# Window 0: nvim
tmux send-keys -t \$SESSION:0 "nvim ." Enter

# Window 1: repo shell with left/right split
tmux new-window -t \$SESSION -n "repo" -c \$REPO
tmux split-window -h -t \$SESSION:1 -c \$REPO
tmux select-pane -t \$SESSION:1.0

# Window 2: journal
tmux new-window -t \$SESSION -n "journal" -c \$JOURNAL

# Window 3: junk drawer
tmux new-window -t \$SESSION -n "scratch"

# Focus window 0 on attach
tmux select-window -t \$SESSION:0

tmux attach -t \$SESSION
EOF
  chmod +x "$HOME/start-day.sh"
  ok "~/start-day.sh written and made executable"

  log "Adding startday alias (vanilla fallback)..."
  add_alias "alias startday=\"\$HOME/start-day.sh\""
fi

ok "Aliases added — run 'source $SHELL_RC' to activate"

# ─────────────────────────────────────────────
# 9. INSTALL TPM PLUGINS
# ─────────────────────────────────────────────
log "Installing tmux plugins via TPM..."
"$HOME/.tmux/plugins/tpm/bin/install_plugins"
ok "Plugins installed"

# ─────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Next steps:"
echo "  1. source $SHELL_RC"
echo "  2. startday"
echo "  3. Inside tmux: Prefix + I  (to confirm plugins are loaded)"
echo ""
echo "  Save session:    Prefix + Ctrl+s"
echo "  Restore session: Prefix + Ctrl+r"
echo ""
