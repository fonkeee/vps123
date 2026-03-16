{ pkgs, ... }: {
  channel = "stable-24.05";
  packages = with pkgs; [
    openssl
    coreutils
    cdrkit
    cloud-utils
    qemu_kvm
    qemu
    tmate
    tmux
    openssh
    unzip
    git
    sudo
    python3
  ];

  env = {
    EDITOR = "nano";
    TMPDIR = "/tmp";
  };

  idx = {
    extensions = [ "Dart-Code.flutter" "Dart-Code.dart-code" ];
    workspace = {
      onStart = {
        startup = ''
          # Clean up tmux first
          tmux kill-server 2>/dev/null || true

          # Create shell-fixes
          cat > ~/.shell-fixes << 'NIXFIX'
[ ! -d "''${TMPDIR:-}" ] && export TMPDIR=/tmp

for _fn in __vsc_prompt_cmd_original __vsc_prompt_cmd __vsc_preexec __vsc_postexec __vsc_preexec_only __vsc_command_output_start __vsc_continuation_start __vsc_continuation_end __vsc_command_complete __vsc_update_cwd; do
  type "$_fn" &>/dev/null || eval "$_fn() { :; }"
done
unset _fn

if [ -n "''${PROMPT_COMMAND:-}" ]; then
  _safe_pc=""
  IFS=';' read -ra _cmds <<< "$PROMPT_COMMAND"
  for _c in "''${_cmds[@]}"; do
    _c=$(echo "$_c" | xargs)
    [ -z "$_c" ] && continue
    _first=$(echo "$_c" | awk '{print $1}')
    if type "$_first" &>/dev/null; then
      [ -n "$_safe_pc" ] && _safe_pc="$_safe_pc;$_c" || _safe_pc="$_c"
    fi
  done
  PROMPT_COMMAND="$_safe_pc"
  unset _safe_pc _cmds _c _first
fi

case "$TERM" in
  dumb|"") export TERM=xterm-256color ;;
esac

: "''${LANG:=en_US.UTF-8}"
export LANG
export LC_ALL="''${LC_ALL:-$LANG}"

export GPG_TTY=$(tty 2>/dev/null || echo /dev/tty)

[ -n "''${SSH_AUTH_SOCK:-}" ] && [ ! -S "$SSH_AUTH_SOCK" ] && unset SSH_AUTH_SOCK

[ -n "''${DISPLAY:-}" ] && ! test -e "/tmp/.X11-unix/X''${DISPLAY#:}" 2>/dev/null && unset DISPLAY

if [ ! -d "''${XDG_RUNTIME_DIR:-}" ]; then
  _xdg="/tmp/runtime-$(id -u)"
  mkdir -p "$_xdg" 2>/dev/null
  chmod 700 "$_xdg" 2>/dev/null
  export XDG_RUNTIME_DIR="$_xdg"
  unset _xdg
fi

[ ! -d "''${HOME:-}" ] && export HOME=$(eval echo "~$(whoami)")

[ -n "$TMUX" ] && export SHELL="''${SHELL:-/bin/bash}"

[ -f ~/.tmate_link ] && . ~/.tmate_link

true
NIXFIX

          # Create bashrc with auto-display of startup info
          cat > ~/.bashrc << 'BASHRC'
# Source shell fixes
[ -f ~/.shell-fixes ] && . ~/.shell-fixes

# Source tmate link
[ -f ~/.tmate_link ] && . ~/.tmate_link

# Auto-display startup info (only once per session, only in interactive shell)
if [[ $- == *i* ]] && [ -z "$STARTUP_INFO_SHOWN" ]; then
  export STARTUP_INFO_SHOWN=1
  
  # Wait for startup to complete (max 90 seconds)
  _wait_count=0
  while [ ! -f /tmp/startup_complete ] && [ $_wait_count -lt 90 ]; do
    sleep 1
    _wait_count=$((_wait_count + 1))
  done
  
  # Show the info
  if [ -f /tmp/startup_info ]; then
    cat /tmp/startup_info
    # Reload tmate link in case it was updated
    [ -f ~/.tmate_link ] && . ~/.tmate_link
  fi
  unset _wait_count
fi

# Function to get current tmate links
get_tmate_link() {
  if [ -f ~/.tmate_link ]; then
    . ~/.tmate_link
    echo ""
    echo "  Connect via terminal:  $TMATE_SSH"
    echo "  Connect via browser:   $TMATE_WEB"
    echo ""
  else
    echo "No tmate link available yet"
  fi
}
BASHRC

          # Also set up zshrc and profile
          cat > ~/.zshrc << 'ZSHRC'
[ -f ~/.shell-fixes ] && . ~/.shell-fixes
[ -f ~/.tmate_link ] && . ~/.tmate_link

if [[ -o interactive ]] && [ -z "$STARTUP_INFO_SHOWN" ]; then
  export STARTUP_INFO_SHOWN=1
  _wait_count=0
  while [ ! -f /tmp/startup_complete ] && [ $_wait_count -lt 90 ]; do
    sleep 1
    _wait_count=$((_wait_count + 1))
  done
  if [ -f /tmp/startup_info ]; then
    cat /tmp/startup_info
    [ -f ~/.tmate_link ] && . ~/.tmate_link
  fi
  unset _wait_count
fi

get_tmate_link() {
  if [ -f ~/.tmate_link ]; then
    . ~/.tmate_link
    echo ""
    echo "  Connect via terminal:  $TMATE_SSH"
    echo "  Connect via browser:   $TMATE_WEB"
    echo ""
  else
    echo "No tmate link available yet"
  fi
}
ZSHRC

          cat > ~/.profile << 'PROFILE'
[ -f ~/.shell-fixes ] && . ~/.shell-fixes
[ -f ~/.tmate_link ] && . ~/.tmate_link
PROFILE

          cat > ~/.tmux.conf << 'TMUXCONF'
set-option -g default-terminal "xterm-256color"
set-option -g history-limit 10000
set-option -g default-shell /bin/bash
TMUXCONF

          export TMPDIR=/tmp
          [ -f ~/.shell-fixes ] && . ~/.shell-fixes

          sleep 1

          # Clear old files
          rm -f /tmp/tmate_link /tmp/tmate.sock /tmp/startup_info /tmp/startup_complete

          # Create tmux session starter scripts
          cat > /tmp/start_stayawake.sh << 'STAYAWAKE_SCRIPT'
#!/bin/bash
source ~/.shell-fixes 2>/dev/null
RESTART_COUNT=0

while true; do
  RESTART_COUNT=$((RESTART_COUNT + 1))
  echo ""
  echo "=========================================="
  echo "  STAYAWAKE SCRIPT - Run #$RESTART_COUNT"
  echo "  Started at: $(date)"
  echo "  Press Ctrl+C to restart script"
  echo "  Press Ctrl+B then D to detach"
  echo "=========================================="
  echo ""
  
  (
    trap "exit 130" INT
    python3 <(curl -s https://raw.githubusercontent.com/JishnuTheGamer/24-7/refs/heads/main/24)
  )
  EXIT_CODE=$?
  
  if [ $EXIT_CODE -eq 130 ]; then
    echo ""
    echo "=========================================="
    echo "  Script interrupted (Ctrl+C)"
    echo "  Restarting in 3 seconds..."
    echo "=========================================="
  else
    echo ""
    echo "=========================================="
    echo "  Script exited with code: $EXIT_CODE"
    echo "  Restarting in 3 seconds..."
    echo "=========================================="
  fi
  sleep 3
done
STAYAWAKE_SCRIPT
          chmod +x /tmp/start_stayawake.sh

          cat > /tmp/start_tmate.sh << 'TMATE_SCRIPT'
#!/bin/bash
source ~/.shell-fixes 2>/dev/null
RESTART_COUNT=0

update_tmate_link() {
  local web="$1"
  local ssh="$2"
  local web_ro="$3"
  local ssh_ro="$4"

  cat > ~/.tmate_link << LINKEND
export TMATE_WEB="$web"
export TMATE_SSH="$ssh"
export TMATE_WEB_RO="$web_ro"
export TMATE_SSH_RO="$ssh_ro"
LINKEND
  
  cat > /tmp/startup_info << INFOEND

==========================================
        STARTUP COMPLETE
==========================================

  Connect via terminal:
    $ssh

  Connect via browser:
    $web

  (Updated at: $(date))

------------------------------------------

tmux Sessions:
$(tmux list-sessions 2>/dev/null || echo "  Loading...")

Commands:
  tmux attach -t stayawake  - View keep-alive script
  tmux attach -t tmate_mgr  - View tmate manager
  tmux attach -t VPS        - View VPS/idxtool session
  tmux attach -t watchdog   - View session watchdog
  
  Detach from tmux:    Ctrl+B then D
  Restart script:      Ctrl+C (script restarts, tmux stays)
  Get tmate links:     get_tmate_link

NOTE: All scripts auto-restart after 3 seconds if they exit.
      If tmate restarts, NEW links will be generated.
      WATCHDOG monitors sessions every 10 seconds and
      auto-restarts any dead tmux sessions.

==========================================
INFOEND
}

while true; do
  RESTART_COUNT=$((RESTART_COUNT + 1))
  echo ""
  echo "=========================================="
  echo "  TMATE SESSION - Run #$RESTART_COUNT"
  echo "  Started at: $(date)"
  echo "  Press Ctrl+C to restart"
  echo "  Press Ctrl+B then D to detach"
  echo "=========================================="
  echo ""
  
  rm -f /tmp/tmate.sock

  # Start tmate in detached mode with a named socket
  tmate -S /tmp/tmate.sock new-session -d
  
  # Wait for tmate to be ready
  tmate -S /tmp/tmate.sock wait tmate-ready

  # Capture all 4 links
  TMATE_WEB=$(tmate -S /tmp/tmate.sock display -p '#{tmate_web}')
  TMATE_SSH=$(tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}')
  TMATE_WEB_RO=$(tmate -S /tmp/tmate.sock display -p '#{tmate_web_ro}')
  TMATE_SSH_RO=$(tmate -S /tmp/tmate.sock display -p '#{tmate_ssh_ro}')

  if [ -n "$TMATE_WEB" ]; then
    update_tmate_link "$TMATE_WEB" "$TMATE_SSH" "$TMATE_WEB_RO" "$TMATE_SSH_RO"
    echo ""
    echo "=========================================="
    echo "  TMATE LINKS CAPTURED!"
    echo ""
    echo "  Connect via terminal:"
    echo "    $TMATE_SSH"
    echo ""
    echo "  Connect via browser:"
    echo "    $TMATE_WEB"
    echo "=========================================="
    echo ""
  else
    echo "WARNING: Could not capture tmate links"
  fi

  # Wait for the tmate session to end
  tmate -S /tmp/tmate.sock wait tmate-session-deactivated 2>/dev/null
  EXIT_CODE=$?

  echo ""
  echo "=========================================="
  echo "  tmate session ended (code: $EXIT_CODE)"
  echo "  Restarting in 3 seconds..."
  echo "  NEW LINKS will be generated!"
  echo "=========================================="
  sleep 3
done
TMATE_SCRIPT
          chmod +x /tmp/start_tmate.sh

          cat > /tmp/start_vps.sh << 'VPS_SCRIPT'
#!/bin/bash
source ~/.shell-fixes 2>/dev/null
RESTART_COUNT=0

while true; do
  RESTART_COUNT=$((RESTART_COUNT + 1))
  echo ""
  echo "=========================================="
  echo "  VPS/IDXTOOL SCRIPT - Run #$RESTART_COUNT"
  echo "  Started at: $(date)"
  echo "  Press Ctrl+C to restart script"
  echo "  Press Ctrl+B then D to detach"
  echo "=========================================="
  echo ""
  
  (
    trap "exit 130" INT
    bash <(curl -s https://raw.githubusercontent.com/fonkeee/firebase-studio/refs/heads/main/idxtool.sh)
  )
  EXIT_CODE=$?
  
  if [ $EXIT_CODE -eq 130 ]; then
    echo ""
    echo "=========================================="
    echo "  Script interrupted (Ctrl+C)"
    echo "  Restarting in 3 seconds..."
    echo "=========================================="
  else
    echo ""
    echo "=========================================="
    echo "  Script exited with code: $EXIT_CODE"
    echo "  Restarting in 3 seconds..."
    echo "=========================================="
  fi
  sleep 3
done
VPS_SCRIPT
          chmod +x /tmp/start_vps.sh

          # Create the watchdog script
          cat > /tmp/watchdog.sh << 'WATCHDOG_SCRIPT'
#!/bin/bash
source ~/.shell-fixes 2>/dev/null

echo "=========================================="
echo "  TMUX SESSION WATCHDOG"
echo "  Started at: $(date)"
echo "  Monitoring: stayawake, tmate_mgr, VPS"
echo "  Check interval: 10 seconds"
echo "=========================================="
echo ""

check_and_start_session() {
  local session_name="$1"
  local script_path="$2"
  
  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    echo "[$(date '+%H:%M:%S')] Session '$session_name' not found - RESTARTING..."
    tmux new-session -d -s "$session_name" "bash $script_path"
    sleep 2
    if tmux has-session -t "$session_name" 2>/dev/null; then
      echo "[$(date '+%H:%M:%S')] Session '$session_name' successfully restarted!"
    else
      echo "[$(date '+%H:%M:%S')] WARNING: Failed to restart '$session_name'"
    fi
  fi
}

while true; do
  check_and_start_session "stayawake" "/tmp/start_stayawake.sh"
  check_and_start_session "tmate_mgr" "/tmp/start_tmate.sh"
  check_and_start_session "VPS" "/tmp/start_vps.sh"
  
  sleep 10
done
WATCHDOG_SCRIPT
          chmod +x /tmp/watchdog.sh

          # 1. Start stayawake session
          tmux new-session -d -s stayawake "bash /tmp/start_stayawake.sh"

          # 2. Start tmate manager session
          tmux new-session -d -s tmate_mgr "bash /tmp/start_tmate.sh"

          # 3. Start VPS session
          tmux new-session -d -s VPS "bash /tmp/start_vps.sh"

          # 4. Start watchdog session (monitors and restarts other sessions)
          tmux new-session -d -s watchdog "bash /tmp/watchdog.sh"

          # Wait for tmate links
          for i in $(seq 1 60); do
            if [ -f ~/.tmate_link ]; then
              . ~/.tmate_link
              break
            fi
            sleep 1
          done

          # Build startup info file
          [ -f ~/.tmate_link ] && . ~/.tmate_link
          cat > /tmp/startup_info << INFOEND

==========================================
        STARTUP COMPLETE
==========================================

  Connect via terminal:
    ''${TMATE_SSH:-"Loading... run: get_tmate_link"}

  Connect via browser:
    ''${TMATE_WEB:-"Loading... run: get_tmate_link"}

------------------------------------------

tmux Sessions:
$(tmux list-sessions 2>/dev/null || echo "  Loading...")

Commands:
  tmux attach -t stayawake  - View keep-alive script
  tmux attach -t tmate_mgr  - View tmate manager
  tmux attach -t VPS        - View VPS/idxtool session
  tmux attach -t watchdog   - View session watchdog
  
  Detach from tmux:    Ctrl+B then D
  Restart script:      Ctrl+C (script restarts, tmux stays)
  Get tmate links:     get_tmate_link

NOTE: All scripts auto-restart after 3 seconds if they exit.
      If tmate restarts, NEW links will be generated.
      WATCHDOG monitors sessions every 10 seconds and
      auto-restarts any dead tmux sessions.

==========================================
INFOEND

          # Mark startup complete
          touch /tmp/startup_complete

          true
        '';
      };
    };
    previews = {
      enable = true;
      previews = {
        web = {
          command = [
            "sh"
            "-c"
            "echo '<!DOCTYPE html><html><head></head><body></body></html>' > /tmp/index.html && python3 -m http.server $PORT --bind 0.0.0.0 --directory /tmp"
          ];
          manager = "web";
        };
      };
    };
  };
}
