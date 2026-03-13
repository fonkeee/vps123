{ pkgs, ... }: {
  channel = "stable-24.05";
  packages = with pkgs; [
    openssl
    coreutils
    cdrkit
    cloud-utils
    qemu_kvm
    qemu
    sshx
    screen
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
          # Clean up screens first
          screen -wipe 2>/dev/null || true
          killall screen 2>/dev/null || true
          screen -wipe 2>/dev/null || true

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

[ -n "$STY" ] && export SHELL="''${SHELL:-/bin/bash}"

[ -f ~/.sshx_link ] && . ~/.sshx_link

true
NIXFIX

          # Create bashrc with auto-display of startup info
          cat > ~/.bashrc << 'BASHRC'
# Source shell fixes
[ -f ~/.shell-fixes ] && . ~/.shell-fixes

# Source sshx link
[ -f ~/.sshx_link ] && . ~/.sshx_link

# Disable terminal scroll mode for proper screen scrollback
bind '"\e[5~": ""' 2>/dev/null   # Disable Page Up for history
bind '"\e[6~": ""' 2>/dev/null   # Disable Page Down for history

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
    # Reload sshx link in case it was updated
    [ -f ~/.sshx_link ] && . ~/.sshx_link
  fi
  unset _wait_count
fi

# Function to get current sshx link
get_sshx_link() {
  if [ -f ~/.sshx_link ]; then
    . ~/.sshx_link
    echo "$SSHX_LINK"
  elif [ -f /tmp/sshx_link ]; then
    cat /tmp/sshx_link
  else
    echo "No sshx link available yet"
  fi
}
BASHRC

          # Also set up zshrc and profile
          cat > ~/.zshrc << 'ZSHRC'
[ -f ~/.shell-fixes ] && . ~/.shell-fixes
[ -f ~/.sshx_link ] && . ~/.sshx_link

if [[ -o interactive ]] && [ -z "$STARTUP_INFO_SHOWN" ]; then
  export STARTUP_INFO_SHOWN=1
  _wait_count=0
  while [ ! -f /tmp/startup_complete ] && [ $_wait_count -lt 90 ]; do
    sleep 1
    _wait_count=$((_wait_count + 1))
  done
  if [ -f /tmp/startup_info ]; then
    cat /tmp/startup_info
    [ -f ~/.sshx_link ] && . ~/.sshx_link
  fi
  unset _wait_count
fi

get_sshx_link() {
  if [ -f ~/.sshx_link ]; then
    . ~/.sshx_link
    echo "$SSHX_LINK"
  elif [ -f /tmp/sshx_link ]; then
    cat /tmp/sshx_link
  else
    echo "No sshx link available yet"
  fi
}
ZSHRC

          cat > ~/.profile << 'PROFILE'
[ -f ~/.shell-fixes ] && . ~/.shell-fixes
[ -f ~/.sshx_link ] && . ~/.sshx_link
PROFILE

          # Enhanced screenrc with scrollback support
          cat > ~/.screenrc << 'SCREENRC'
# Terminal settings
setenv TMPDIR /tmp
term xterm-256color
startup_message off

# Scrollback buffer - 50000 lines
defscrollback 50000

# Enable mouse scrolling and terminal scrollback
termcapinfo xterm* ti@:te@

# Alternative scrollback for other terminals
termcapinfo rxvt* ti@:te@
termcapinfo vt100 dl=5\E[M

# Shell settings
shell -$SHELL

# Status line
hardstatus alwayslastline
hardstatus string '%{= kG}[ %{G}%H %{g}][%= %{= kw}%?%-Lw%?%{r}(%{W}%n*%f%t%?(%u)%?%{r})%{w}%?%+Lw%?%?%= %{g}][%{B} %m-%d %{W}%c %{g}]'

# Key bindings for scrollback
# Enter copy/scrollback mode with Ctrl+A then Escape
# Then use Page Up/Down, arrow keys, or mouse wheel to scroll
# Press Escape or q to exit scrollback mode

# Enable UTF-8
defutf8 on

# Visual bell instead of audio
vbell on

# Don't block when a window hangs
nonblock on
SCREENRC

          export TMPDIR=/tmp
          [ -f ~/.shell-fixes ] && . ~/.shell-fixes

          sleep 1

          # Clear old files
          rm -f /tmp/sshx_link /tmp/sshx_output /tmp/startup_info /tmp/startup_complete

          # Create screen session starter scripts
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
  echo "  Press Ctrl+A then D to detach"
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

          cat > /tmp/start_sshx.sh << 'SSHX_SCRIPT'
#!/bin/bash
source ~/.shell-fixes 2>/dev/null
RESTART_COUNT=0

update_sshx_link() {
  local new_link="$1"
  echo "$new_link" > /tmp/sshx_link
  echo "export SSHX_LINK=\"$new_link\"" > ~/.sshx_link
  
  cat > /tmp/startup_info << INFOEND

==========================================
        STARTUP COMPLETE
==========================================

SSHX Link: $new_link
(Updated at: $(date))

Screen Sessions:
$(screen -ls 2>/dev/null | grep -E "stayawake|sshx|VPS|watchdog" || echo "  Loading...")

Commands:
  screen -r stayawake  - View keep-alive script
  screen -r sshx       - View sshx session
  screen -r VPS        - View VPS/idxtool session
  screen -r watchdog   - View session watchdog
  
  Detach from screen:  Ctrl+A then D
  Restart script:      Ctrl+C (script restarts, screen stays)
  Get sshx link:       echo \$SSHX_LINK
                       get_sshx_link
                       cat ~/.sshx_link

SCROLL IN SCREEN:
  Ctrl+A then Escape   - Enter scrollback mode
  Page Up/Down         - Scroll through history
  Arrow keys           - Navigate
  Escape or q          - Exit scrollback mode

==========================================
INFOEND
}

while true; do
  RESTART_COUNT=$((RESTART_COUNT + 1))
  echo ""
  echo "=========================================="
  echo "  SSHX SESSION - Run #$RESTART_COUNT"
  echo "  Started at: $(date)"
  echo "  Press Ctrl+C to restart script"
  echo "  Press Ctrl+A then D to detach"
  echo "=========================================="
  echo ""
  
  rm -f /tmp/sshx_output
  
  (
    trap "exit 130" INT
    sshx 2>&1 | tee /tmp/sshx_output
  ) &
  SSHX_PID=$!
  
  LINK_FOUND=0
  for i in $(seq 1 30); do
    if ! kill -0 $SSHX_PID 2>/dev/null; then
      break
    fi
    if grep -o "https://sshx.io/s/[^#]*#[^ ]*" /tmp/sshx_output > /tmp/sshx_link_new 2>/dev/null; then
      NEW_LINK=$(cat /tmp/sshx_link_new | head -1)
      if [ -n "$NEW_LINK" ]; then
        update_sshx_link "$NEW_LINK"
        echo ""
        echo "=========================================="
        echo "  NEW SSHX LINK CAPTURED!"
        echo "  $NEW_LINK"
        echo "=========================================="
        echo ""
        LINK_FOUND=1
        break
      fi
    fi
    sleep 1
  done
  
  if [ $LINK_FOUND -eq 0 ]; then
    echo "WARNING: Could not capture sshx link within 30 seconds"
  fi
  
  wait $SSHX_PID 2>/dev/null
  EXIT_CODE=$?
  
  if [ $EXIT_CODE -eq 130 ]; then
    echo ""
    echo "=========================================="
    echo "  sshx interrupted (Ctrl+C)"
    echo "  Restarting in 3 seconds..."
    echo "  A NEW LINK will be generated!"
    echo "=========================================="
  else
    echo ""
    echo "=========================================="
    echo "  sshx exited with code: $EXIT_CODE"
    echo "  Restarting in 3 seconds..."
    echo "  A NEW LINK will be generated!"
    echo "=========================================="
  fi
  sleep 3
done
SSHX_SCRIPT
          chmod +x /tmp/start_sshx.sh

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
  echo "  Press Ctrl+A then D to detach"
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
echo "  SCREEN SESSION WATCHDOG"
echo "  Started at: $(date)"
echo "  Monitoring: stayawake, sshx, VPS"
echo "  Check interval: 10 seconds"
echo "=========================================="
echo ""

check_and_start_session() {
  local session_name="$1"
  local script_path="$2"
  
  if ! screen -ls | grep -q "\.$session_name[[:space:]]"; then
    echo "[$(date '+%H:%M:%S')] Session '$session_name' not found - RESTARTING..."
    screen -dmS "$session_name" bash "$script_path"
    sleep 2
    if screen -ls | grep -q "\.$session_name[[:space:]]"; then
      echo "[$(date '+%H:%M:%S')] Session '$session_name' successfully restarted!"
    else
      echo "[$(date '+%H:%M:%S')] WARNING: Failed to restart '$session_name'"
    fi
  fi
}

while true; do
  check_and_start_session "stayawake" "/tmp/start_stayawake.sh"
  check_and_start_session "sshx" "/tmp/start_sshx.sh"
  check_and_start_session "VPS" "/tmp/start_vps.sh"
  
  screen -wipe 2>/dev/null || true
  
  sleep 10
done
WATCHDOG_SCRIPT
          chmod +x /tmp/watchdog.sh

          # 1. Start stayawake session
          screen -dmS stayawake bash /tmp/start_stayawake.sh

          # 2. Start sshx session
          screen -dmS sshx bash /tmp/start_sshx.sh

          # 3. Start VPS session
          screen -dmS VPS bash /tmp/start_vps.sh

          # 4. Start watchdog session (monitors and restarts other sessions)
          screen -dmS watchdog bash /tmp/watchdog.sh

          # Wait for sshx link
          SSHX_LINK=""
          for i in $(seq 1 60); do
            if [ -s /tmp/sshx_link ]; then
              SSHX_LINK=$(cat /tmp/sshx_link | head -1)
              echo "export SSHX_LINK=\"$SSHX_LINK\"" > ~/.sshx_link
              break
            fi
            sleep 1
          done

          # Build startup info file
          cat > /tmp/startup_info << INFOEND

==========================================
        STARTUP COMPLETE
==========================================

SSHX Link: ''${SSHX_LINK:-"Loading... run: cat /tmp/sshx_link"}

Screen Sessions:
$(screen -ls 2>/dev/null | grep -E "stayawake|sshx|VPS|watchdog" || echo "  Loading...")

Commands:
  screen -r stayawake  - View keep-alive script
  screen -r sshx       - View sshx session
  screen -r VPS        - View VPS/idxtool session
  screen -r watchdog   - View session watchdog
  
  Detach from screen:  Ctrl+A then D
  Restart script:      Ctrl+C (script restarts, screen stays)
  Get sshx link:       echo \$SSHX_LINK
                       get_sshx_link
                       cat ~/.sshx_link

SCROLL IN SCREEN:
  Ctrl+A then Escape   - Enter scrollback mode
  Page Up/Down         - Scroll through history
  Arrow keys           - Navigate
  Escape or q          - Exit scrollback mode

NOTE: All scripts auto-restart after 3 seconds if they exit.
      Ctrl+C restarts the script, NOT the screen session.
      If sshx restarts, a NEW link will be generated.
      WATCHDOG monitors sessions every 10 seconds and
      auto-restarts any deleted screen sessions.

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
