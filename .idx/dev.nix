{ pkgs, ... }: {
  channel = "stable-24.05";
  packages = with pkgs; [
    openssl
    coreutils
    cdrkit
    cloud-utils
    qemu_kvm
    qemu
    upterm
    screen
    openssh
    unzip
    git
    sudo
    python3
    tmux
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
          killall upterm 2>/dev/null || true
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

[ -f ~/.upterm_link ] && . ~/.upterm_link

true
NIXFIX

          # Create bashrc with auto-display of startup info
          cat > ~/.bashrc << 'BASHRC'
# Source shell fixes
[ -f ~/.shell-fixes ] && . ~/.shell-fixes

# Source upterm link
[ -f ~/.upterm_link ] && . ~/.upterm_link

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
    # Reload upterm link in case it was updated
    [ -f ~/.upterm_link ] && . ~/.upterm_link
  fi
  unset _wait_count
fi

# Function to get current upterm info
get_upterm_info() {
  if [ -f ~/.upterm_link ]; then
    . ~/.upterm_link
    echo "=========================================="
    echo "SSH Command:"
    echo "  $UPTERM_SSH"
    echo ""
    echo "Web Terminal:"
    echo "  $UPTERM_WEB"
    echo "=========================================="
  else
    echo "No upterm info available yet"
    echo "Try: screen -r upterm"
  fi
}

# Alias for quick access
alias upinfo='get_upterm_info'
BASHRC

          # Also set up zshrc and profile
          cat > ~/.zshrc << 'ZSHRC'
[ -f ~/.shell-fixes ] && . ~/.shell-fixes
[ -f ~/.upterm_link ] && . ~/.upterm_link

if [[ -o interactive ]] && [ -z "$STARTUP_INFO_SHOWN" ]; then
  export STARTUP_INFO_SHOWN=1
  _wait_count=0
  while [ ! -f /tmp/startup_complete ] && [ $_wait_count -lt 90 ]; do
    sleep 1
    _wait_count=$((_wait_count + 1))
  done
  if [ -f /tmp/startup_info ]; then
    cat /tmp/startup_info
    [ -f ~/.upterm_link ] && . ~/.upterm_link
  fi
  unset _wait_count
fi

get_upterm_info() {
  if [ -f ~/.upterm_link ]; then
    . ~/.upterm_link
    echo "=========================================="
    echo "SSH Command:"
    echo "  $UPTERM_SSH"
    echo ""
    echo "Web Terminal:"
    echo "  $UPTERM_WEB"
    echo "=========================================="
  else
    echo "No upterm info available yet"
  fi
}
alias upinfo='get_upterm_info'
ZSHRC

          cat > ~/.profile << 'PROFILE'
[ -f ~/.shell-fixes ] && . ~/.shell-fixes
[ -f ~/.upterm_link ] && . ~/.upterm_link
PROFILE

          cat > ~/.screenrc << 'SCREENRC'
setenv TMPDIR /tmp
term xterm-256color
defscrollback 10000
shell -$SHELL
startup_message off
SCREENRC

          export TMPDIR=/tmp
          [ -f ~/.shell-fixes ] && . ~/.shell-fixes

          sleep 1

          # Clear old files
          rm -f /tmp/upterm_ssh /tmp/upterm_web /tmp/upterm_output /tmp/startup_info /tmp/startup_complete

          # Generate SSH host key if not exists
          mkdir -p ~/.ssh
          chmod 700 ~/.ssh
          [ ! -f ~/.ssh/id_rsa ] && ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -q
          [ ! -f ~/.ssh/id_ed25519 ] && ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q
          cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys 2>/dev/null
          cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys 2>/dev/null
          chmod 600 ~/.ssh/authorized_keys 2>/dev/null

          # Create screen session starter scripts
          cat > /tmp/start_stayawake.sh << 'STAYAWAKE_SCRIPT'
#!/bin/bash
source ~/.shell-fixes 2>/dev/null
RESTART_COUNT=0

while true; do
  RESTART_COUNT=$((RESTART_COUNT + 1))
  echo ""
  echo "=========================================="
  echo " STAYAWAKE SCRIPT - Run #$RESTART_COUNT"
  echo " Started at: $(date)"
  echo " Press Ctrl+C to restart script"
  echo " Press Ctrl+A then D to detach"
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
    echo " Script interrupted (Ctrl+C)"
    echo " Restarting in 3 seconds..."
    echo "=========================================="
  else
    echo ""
    echo "=========================================="
    echo " Script exited with code: $EXIT_CODE"
    echo " Restarting in 3 seconds..."
    echo "=========================================="
  fi
  sleep 3
done
STAYAWAKE_SCRIPT
          chmod +x /tmp/start_stayawake.sh

          cat > /tmp/start_upterm.sh << 'UPTERM_SCRIPT'
#!/bin/bash
source ~/.shell-fixes 2>/dev/null
RESTART_COUNT=0

update_upterm_info() {
  local ssh_cmd="$1"
  local web_link="$2"
  
  echo "$ssh_cmd" > /tmp/upterm_ssh
  echo "$web_link" > /tmp/upterm_web
  
  cat > ~/.upterm_link << LINKEND
export UPTERM_SSH="$ssh_cmd"
export UPTERM_WEB="$web_link"
LINKEND

  cat > /tmp/startup_info << INFOEND

==========================================
STARTUP COMPLETE
(Updated at: $(date))

==========================================
UPTERM CONNECTION INFO
==========================================
SSH Command:
  $ssh_cmd

Web Terminal:
  $web_link
==========================================

Screen Sessions:
$(screen -ls 2>/dev/null | grep -E "stayawake|upterm|VPS|watchdog" || echo "  Loading...")

Commands:
  screen -r stayawake  - View keep-alive script
  screen -r upterm     - View upterm session
  screen -r VPS        - View VPS/idxtool session
  screen -r watchdog   - View session watchdog

Detach from screen: Ctrl+A then D
Restart script: Ctrl+C (script restarts, screen stays)
Get upterm info: get_upterm_info  OR  upinfo
                 cat ~/.upterm_link

==========================================
INFOEND

  touch /tmp/startup_complete
}

while true; do
  RESTART_COUNT=$((RESTART_COUNT + 1))
  echo ""
  echo "=========================================="
  echo " UPTERM SESSION - Run #$RESTART_COUNT"
  echo " Started at: $(date)"
  echo " Press Ctrl+C to restart script"
  echo " Press Ctrl+A then D to detach"
  echo "=========================================="
  echo ""

  rm -f /tmp/upterm_output /tmp/upterm_socket

  # Create a socket path for upterm
  export UPTERM_ADMIN_SOCKET="/tmp/upterm_socket_$$"
  
  # Start upterm and capture output
  echo "Starting upterm session..."
  
  (
    trap "exit 130" INT
    upterm host --server ssh://uptermd.upterm.dev:22 --force-command bash -- bash 2>&1 | tee /tmp/upterm_output &
    UPTERM_INNER_PID=$!
    
    # Wait for upterm to initialize
    sleep 3
    
    # Keep checking for session info
    while kill -0 $UPTERM_INNER_PID 2>/dev/null; do
      sleep 5
    done
  ) &
  UPTERM_PID=$!

  echo "Waiting for upterm to initialize..."
  sleep 5

  LINK_FOUND=0
  for i in $(seq 1 60); do
    if ! kill -0 $UPTERM_PID 2>/dev/null; then
      echo "Upterm process ended prematurely"
      break
    fi
    
    # Method 1: Try upterm session current
    SESSION_OUTPUT=$(upterm session current 2>&1)
    
    if echo "$SESSION_OUTPUT" | grep -q "SSH Session:"; then
      SSH_CMD=$(echo "$SESSION_OUTPUT" | grep "SSH Session:" | sed 's/.*SSH Session:[[:space:]]*//' | tr -d '\n')
      WEB_LINK=$(echo "$SESSION_OUTPUT" | grep "Web Terminal:" | sed 's/.*Web Terminal:[[:space:]]*//' | tr -d '\n')
      
      if [ -n "$SSH_CMD" ]; then
        # If no web link found, construct it from SSH session
        if [ -z "$WEB_LINK" ]; then
          SESSION_ID=$(echo "$SSH_CMD" | grep -oE '[^@:]+:[^@]+' | head -1 | cut -d: -f1)
          if [ -n "$SESSION_ID" ]; then
            WEB_LINK="https://upterm.dev/s/$SESSION_ID"
          fi
        fi
        
        update_upterm_info "$SSH_CMD" "$WEB_LINK"
        echo ""
        echo "=========================================="
        echo " UPTERM SESSION READY!"
        echo ""
        echo " SSH Command:"
        echo "   $SSH_CMD"
        echo ""
        echo " Web Terminal:"
        echo "   $WEB_LINK"
        echo "=========================================="
        echo ""
        LINK_FOUND=1
        break
      fi
    fi
    
    # Method 2: Parse from output file
    if [ -f /tmp/upterm_output ] && [ -s /tmp/upterm_output ]; then
      SSH_CMD=$(grep -i "ssh session:" /tmp/upterm_output 2>/dev/null | tail -1 | sed 's/.*[Ss][Ss][Hh] [Ss]ession:[[:space:]]*//' | tr -d '\n')
      WEB_LINK=$(grep -i "web terminal:" /tmp/upterm_output 2>/dev/null | tail -1 | sed 's/.*[Ww]eb [Tt]erminal:[[:space:]]*//' | tr -d '\n')
      
      if [ -z "$SSH_CMD" ]; then
        SSH_CMD=$(grep -oE "ssh [a-zA-Z0-9]+:[a-zA-Z0-9]+@[a-zA-Z0-9.-]+" /tmp/upterm_output 2>/dev/null | tail -1)
      fi
      
      if [ -n "$SSH_CMD" ]; then
        if [ -z "$WEB_LINK" ]; then
          SESSION_ID=$(echo "$SSH_CMD" | grep -oE '[^@:]+:[^@]+' | head -1 | cut -d: -f1)
          [ -n "$SESSION_ID" ] && WEB_LINK="https://upterm.dev/s/$SESSION_ID"
        fi
        
        update_upterm_info "$SSH_CMD" "$WEB_LINK"
        echo ""
        echo "=========================================="
        echo " UPTERM SESSION READY!"
        echo ""
        echo " SSH Command:"
        echo "   $SSH_CMD"
        echo ""
        echo " Web Terminal:"
        echo "   $WEB_LINK"
        echo "=========================================="
        echo ""
        LINK_FOUND=1
        break
      fi
    fi
    
    echo "Waiting for upterm session... ($i/60)"
    sleep 2
  done

  if [ $LINK_FOUND -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo " WARNING: Could not capture upterm info"
    echo " Trying manual check..."
    echo "=========================================="
    echo ""
    echo "Output file contents:"
    cat /tmp/upterm_output 2>/dev/null || echo "(empty)"
    echo ""
    echo "Session current output:"
    upterm session current 2>&1 || echo "(failed)"
  fi

  # Wait for the upterm process
  wait $UPTERM_PID 2>/dev/null
  EXIT_CODE=$?

  if [ $EXIT_CODE -eq 130 ]; then
    echo ""
    echo "=========================================="
    echo " upterm interrupted (Ctrl+C)"
    echo " Restarting in 3 seconds..."
    echo " NEW session will be created!"
    echo "=========================================="
  else
    echo ""
    echo "=========================================="
    echo " upterm exited with code: $EXIT_CODE"
    echo " Restarting in 3 seconds..."
    echo " NEW session will be created!"
    echo "=========================================="
  fi
  
  # Cleanup
  killall upterm 2>/dev/null
  sleep 3
done
UPTERM_SCRIPT
          chmod +x /tmp/start_upterm.sh

          cat > /tmp/start_vps.sh << 'VPS_SCRIPT'
#!/bin/bash
source ~/.shell-fixes 2>/dev/null
RESTART_COUNT=0

while true; do
  RESTART_COUNT=$((RESTART_COUNT + 1))
  echo ""
  echo "=========================================="
  echo " VPS/IDXTOOL SCRIPT - Run #$RESTART_COUNT"
  echo " Started at: $(date)"
  echo " Press Ctrl+C to restart script"
  echo " Press Ctrl+A then D to detach"
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
    echo " Script interrupted (Ctrl+C)"
    echo " Restarting in 3 seconds..."
    echo "=========================================="
  else
    echo ""
    echo "=========================================="
    echo " Script exited with code: $EXIT_CODE"
    echo " Restarting in 3 seconds..."
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
echo " SCREEN SESSION WATCHDOG"
echo " Started at: $(date)"
echo " Monitoring: stayawake, upterm, VPS"
echo " Check interval: 10 seconds"
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
  check_and_start_session "upterm" "/tmp/start_upterm.sh"
  check_and_start_session "VPS" "/tmp/start_vps.sh"

  screen -wipe 2>/dev/null || true

  sleep 10
done
WATCHDOG_SCRIPT
          chmod +x /tmp/watchdog.sh

          # 1. Start stayawake session
          screen -dmS stayawake bash /tmp/start_stayawake.sh

          # 2. Start upterm session
          screen -dmS upterm bash /tmp/start_upterm.sh

          # 3. Start VPS session
          screen -dmS VPS bash /tmp/start_vps.sh

          # 4. Start watchdog session
          screen -dmS watchdog bash /tmp/watchdog.sh

          # Wait for upterm info with longer timeout
          UPTERM_SSH=""
          UPTERM_WEB=""
          for i in $(seq 1 120); do
            if [ -s /tmp/upterm_ssh ] && [ -s /tmp/upterm_web ]; then
              UPTERM_SSH=$(cat /tmp/upterm_ssh | head -1)
              UPTERM_WEB=$(cat /tmp/upterm_web | head -1)
              cat > ~/.upterm_link << LINKEND
export UPTERM_SSH="$UPTERM_SSH"
export UPTERM_WEB="$UPTERM_WEB"
LINKEND
              break
            fi
            sleep 1
          done

          # Build startup info file
          if [ -n "$UPTERM_SSH" ]; then
            cat > /tmp/startup_info << INFOEND
==========================================
STARTUP COMPLETE
(Updated at: $(date))

==========================================
UPTERM CONNECTION INFO
==========================================
SSH Command:
  $UPTERM_SSH

Web Terminal:
  $UPTERM_WEB
==========================================

Screen Sessions:
$(screen -ls 2>/dev/null | grep -E "stayawake|upterm|VPS|watchdog" || echo "  Loading...")

Commands:
  screen -r stayawake  - View keep-alive script
  screen -r upterm     - View upterm session
  screen -r VPS        - View VPS/idxtool session
  screen -r watchdog   - View session watchdog

Detach from screen: Ctrl+A then D
Get upterm info: get_upterm_info  OR  upinfo

==========================================
INFOEND
          else
            cat > /tmp/startup_info << INFOEND
==========================================
STARTUP COMPLETE
(Updated at: $(date))

==========================================
UPTERM CONNECTION INFO
==========================================
Status: Still initializing...

To get upterm info manually:
  screen -r upterm     (view the session)
  get_upterm_info      (after session starts)
  upinfo               (shortcut)
==========================================

Screen Sessions:
$(screen -ls 2>/dev/null | grep -E "stayawake|upterm|VPS|watchdog" || echo "  Loading...")

Commands:
  screen -r stayawake  - View keep-alive script
  screen -r upterm     - View upterm session
  screen -r VPS        - View VPS/idxtool session
  screen -r watchdog   - View session watchdog

==========================================
INFOEND
          fi

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
