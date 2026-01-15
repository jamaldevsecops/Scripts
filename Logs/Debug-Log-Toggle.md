# 🐞 Debug Logging Toggle Tool

A production-ready Python utility to enable or disable **DEBUG logging**
for multiple components by modifying their respective `logback.xml`
files.\
It supports ⏱️ scheduled auto-revert, 🧩 multi-component control, 📣
Microsoft Teams notifications, and 🛡️ safe CLI interaction.

------------------------------------------------------------------------

## ✨ Features

-   🐞 Enable / Disable DEBUG logging per component
-   🧩 Supports multiple components (syscore, bds, etc.)
-   ⏱️ Auto-revert at a scheduled time using background daemon
-   📣 Microsoft Teams webhook notifications (well-formatted cards)
-   👤 Shows username, 🖥️ hostname, ⌛ duration, and 📦 component
-   ⌨️ Safe input handling (retry on invalid input, clean Ctrl+C exit)
-   🐧 Works on RHEL, Ubuntu, Debian, Alma, Rocky
-   🔐 UTF-8 safe, no locale or encoding issues

------------------------------------------------------------------------

## 🧩 Components Configuration

Edit this section in the script to add or modify components:

``` python
COMPONENTS = {
    "syscore": {"config": "/home/syscore/cfg/logback.xml"},
    "bds": {"config": "/var/log/bds/xyz/logback.xml"}
}
```

➕ To add a new component:

``` python
"newapp": {"config": "/opt/newapp/conf/logback.xml"}
```

No other code changes are required.

------------------------------------------------------------------------

## ▶️ Usage

### 🐞 Enable DEBUG for a component

``` bash
python3 debug_logging.py enable
```

You will be prompted to: - 🧩 Select component\
- ⏰ Enter end time (HH:MM)\
- 📅 Enter end date (YYYY-MM-DD)

If you press **Enter**, default values will be used automatically.

------------------------------------------------------------------------

### 🛑 Disable DEBUG manually

``` bash
python3 debug_logging.py disable
```

Select the component and DEBUG will be reverted immediately.

------------------------------------------------------------------------

## 💻 Sample Interaction

``` text
=== DEBUG Enable ===

Select component:
1) syscore -> /home/syscore/cfg/logback.xml
2) bds     -> /var/log/bds/xyz/logback.xml

Today : 2026-01-13
Time  : 15:59:15

End time (HH:MM, default 18:00): 16:30
End date (YYYY-MM-DD, default 2026-01-13):

DEBUG enabled for component: syscore
Duration: 00h 31m
```

------------------------------------------------------------------------

## 📣 Webhook Notifications (Microsoft Teams)

Each notification contains:

-   📦 Component name\
-   🖥️ Hostname\
-   👤 Username\
-   📄 Config path\
-   ⌛ Duration (when enabled)\
-   ⏱️ Disabled time (when disabled)

🎨 Visual indicators: - 🟡 Yellow card = DEBUG Enabled\
- 🟢 Green card = DEBUG Disabled

This provides strong **audit visibility** for operations teams.

------------------------------------------------------------------------

## 📁 File Locations Used

  Path                             Purpose
  -------------------------------- -------------------------------------
  `/var/lib/debug_toggle/state/`   Stores schedule state per component
  `/var/lib/debug_toggle/pid/`     Stores daemon PID files
  `/var/log/debug_toggle/`         Script execution logs

------------------------------------------------------------------------

## 🔐 Permissions Required

The script must be able to:

-   ✍️ Read/write component `logback.xml` files\
-   📂 Write under `/var/lib/debug_toggle/`\
-   📝 Write logs under `/var/log/debug_toggle/`

Run as **root** or configure appropriate **sudo permissions**.

------------------------------------------------------------------------

## 🧠 Operational Best Practices

-   ⏳ Always use short DEBUG durations\
-   🌙 Avoid leaving DEBUG enabled overnight\
-   📣 Rely on Teams notifications for visibility\
-   📜 Maintain audit trail via logs\
-   🧩 Add new components centrally via config

------------------------------------------------------------------------

## 🚀 Possible Future Enhancements

These can be added easily if needed:

-   📊 `status` command to show active DEBUG sessions\
-   📝 Require reason before enabling DEBUG\
-   📄 YAML config instead of inline dictionary\
-   ⚙️ systemd service instead of background daemon\
-   🎫 Change ID / ticket reference\
-   🔒 Locking to prevent multiple users enabling same component
    simultaneously

------------------------------------------------------------------------

## 👨‍💻 Author Notes

This tool is designed with **SRE / DevOps operational safety** in mind:

-   ✅ Safe defaults\
-   ✅ Predictable behavior\
-   ✅ Clean UI in Teams\
-   ✅ Portable across Linux distributions\
-   ✅ No dependency on locale or terminal quirks

------------------------------------------------------------------------

## 📜 Full Script (Python)
```
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import json
import time
import re
import shutil
import urllib.request
import subprocess
import socket
import getpass
from datetime import datetime, timedelta

# ================= COMPONENT CONFIG =================
COMPONENTS = {
    "syscore": {"config": "/tmp/logback.xml"},
    "bds": {"config": "/home/bds/cfg/logback.xml"}
}

# ================= PATHS =================
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

BASE_DIR  = os.path.join(SCRIPT_DIR, "script_data")
STATE_DIR = os.path.join(BASE_DIR, "state")
PID_DIR   = os.path.join(BASE_DIR, "pid")
LOG_DIR   = os.path.join(BASE_DIR, "logs")
LOG_FILE  = os.path.join(LOG_DIR, "log_toggle.log")

# ================= CONFIG =================
WEBHOOK_URL = "https://my.webhook.office.com"

DEFAULT_END_TIME = "18:00"
CHECK_INTERVAL = 5  # seconds

# ================= PROXY CONFIG =================
USE_PROXY = False
PROXY_CONFIG = {
    "http":  "http://10.10.2.200:8080",
    "https": "http://10.10.2.200:8080",
}

# ================= UTILITIES =================
def ensure_dirs():
    for d in (STATE_DIR, PID_DIR, LOG_DIR):
        os.makedirs(d, exist_ok=True)

def log(msg):
    ensure_dirs()
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"[{datetime.now():%F %T}] {msg}\n")

def get_hostname():
    return socket.gethostname()

def get_username():
    return getpass.getuser()

def format_duration(delta):
    total_seconds = max(0, int(delta.total_seconds()))
    hours = total_seconds // 3600
    minutes = (total_seconds % 3600) // 60
    return f"{hours:02d}h {minutes:02d}m"

def send_webhook(title, body, color):
    payload = {
        "@type": "MessageCard",
        "@context": "http://schema.org/extensions",
        "summary": title,
        "themeColor": color,
        "title": title,
        "text": body
    }

    data = json.dumps(payload).encode("utf-8")

    if USE_PROXY:
        proxy_handler = urllib.request.ProxyHandler(PROXY_CONFIG)
    else:
        proxy_handler = urllib.request.ProxyHandler({})

    opener = urllib.request.build_opener(proxy_handler)

    try:
        req = urllib.request.Request(
            WEBHOOK_URL,
            data=data,
            headers={"Content-Type": "application/json"}
        )
        opener.open(req, timeout=10)
    except Exception as e:
        log(f"Webhook failed: {e}")

# ================= LOG LEVEL =================
def get_current_level(config_file):
    try:
        with open(config_file, encoding="utf-8") as f:
            content = f.read().upper()

        if 'LEVEL="DEBUG"' in content or '<LEVEL>DEBUG</LEVEL>' in content:
            return "DEBUG"
        return "INFO"
    except:
        return "UNKNOWN"

# ================= XML UPDATE =================
def replace_level(config_file, level):
    with open(config_file, encoding="utf-8") as f:
        content = f.read()

    content, count_attr = re.subn(
        r'(level=")[A-Z]+(")',
        rf'\1{level}\2',
        content,
        flags=re.IGNORECASE
    )

    content, count_tag = re.subn(
        r'(<level>)[A-Z]+(</level>)',
        rf'\1{level}\2',
        content,
        flags=re.IGNORECASE
    )

    if count_attr + count_tag == 0:
        raise RuntimeError("No log level entries found")

    with open(config_file, "w", encoding="utf-8") as f:
        f.write(content)

# ================= INPUT =================
def ask_time(prompt, default):
    while True:
        try:
            value = input(f"{prompt} (HH:MM, default {default}): ").strip()
            if not value:
                return default
            datetime.strptime(value, "%H:%M")
            return value
        except ValueError:
            print("Invalid time format. Use HH:MM (e.g. 16:30).")
        except KeyboardInterrupt:
            sys.exit(130)

def ask_date(prompt, default):
    while True:
        try:
            value = input(f"{prompt} (YYYY-MM-DD, default {default}): ").strip()
            if not value:
                return default
            datetime.strptime(value, "%Y-%m-%d")
            return value
        except ValueError:
            print("Invalid date format. Use YYYY-MM-DD.")
        except KeyboardInterrupt:
            sys.exit(130)

def select_component():
    print("\nSelect component:\n")
    keys = list(COMPONENTS.keys())

    for i, name in enumerate(keys, 1):
        print(f"{i}) {name:<10} -> {COMPONENTS[name]['config']}")

    while True:
        try:
            choice = input(f"\nEnter choice (1-{len(keys)}): ").strip()
            idx = int(choice) - 1
            if idx < 0 or idx >= len(keys):
                raise ValueError
            return keys[idx]
        except:
            print("Invalid selection.")

# ================= DAEMON =================
def daemon(component):
    ensure_dirs()
    pid_file = os.path.join(PID_DIR, f"{component}.pid")
    state_file = os.path.join(STATE_DIR, f"{component}.json")

    log(f"Daemon started for {component} pid={os.getpid()}")

    with open(pid_file, "w") as f:
        f.write(str(os.getpid()))

    while True:
        try:
            if os.path.exists(state_file):
                with open(state_file) as f:
                    state = json.load(f)

                if datetime.now() >= datetime.fromisoformat(state["revert_at"]):
                    replace_level(state["config"], "INFO")

                    body = f"""
<b>DEBUG logging has been DISABLED (Auto)</b><br><br>
<table>
<tr><td><b>Component</b></td><td>{component}</td></tr>
<tr><td><b>Host</b></td><td>{get_hostname()}</td></tr>
<tr><td><b>Config</b></td><td>{state["config"]}</td></tr>
<tr><td><b>Disabled at</b></td><td>{datetime.now():%F %T}</td></tr>
</table>
"""
                    send_webhook("DEBUG Disabled", body.strip(), "2ECC71")
                    log(f"Auto-disabled {component}")

                    os.remove(state_file)
                    os.remove(pid_file)
                    sys.exit(0)

        except Exception as e:
            log(f"daemon error {component}: {e}")

        time.sleep(CHECK_INTERVAL)

def start_daemon(component):
    subprocess.Popen(
        [sys.executable, os.path.abspath(__file__), "daemon", component],
        cwd=SCRIPT_DIR,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True
    )

# ================= STATUS =================
def status():
    now = datetime.now()
    print()

    for name, cfg in COMPONENTS.items():
        config = cfg["config"]
        state_file = os.path.join(STATE_DIR, f"{name}.json")

        level = get_current_level(config)

        if level == "DEBUG" and os.path.exists(state_file):
            with open(state_file) as f:
                state = json.load(f)
            revert = datetime.fromisoformat(state["revert_at"])
            remaining = format_duration(revert - now)
            print(f"{name:<10}: DEBUG (expires in {remaining})")

        elif level == "DEBUG":
            print(f"{name:<10}: DEBUG (no auto-disable scheduled)")

        else:
            print(f"{name:<10}: INFO")

    print()

# ================= ENABLE =================
def enable():
    component = select_component()
    config = COMPONENTS[component]["config"]

    if get_current_level(config) == "DEBUG":
        choice = input(f"\nDEBUG already enabled for {component}. Disable instead? (y/N): ").lower()
        if choice == "y":
            disable()
        return

    now = datetime.now()
    print("\n=== Enable DEBUG ===")
    print(f"Today : {now:%F}")
    print(f"Time  : {now:%T}\n")

    end_time = ask_time("End time", DEFAULT_END_TIME)
    end_date = ask_date("End date", now.strftime("%F"))

    revert_at = datetime.strptime(f"{end_date} {end_time}", "%Y-%m-%d %H:%M")
    if revert_at <= now:
        revert_at += timedelta(days=1)

    ensure_dirs()
    shutil.copy2(config, f"{config}.bak_{now:%F_%H-%M-%S}")
    replace_level(config, "DEBUG")

    state_file = os.path.join(STATE_DIR, f"{component}.json")
    with open(state_file, "w") as f:
        json.dump({"revert_at": revert_at.isoformat(), "config": config}, f)

    duration = format_duration(revert_at - now)

    body = f"""
<b>DEBUG logging has been ENABLED</b><br><br>
<table>
<tr><td><b>Component</b></td><td>{component}</td></tr>
<tr><td><b>Host</b></td><td>{get_hostname()}</td></tr>
<tr><td><b>User</b></td><td>{get_username()}</td></tr>
<tr><td><b>Config</b></td><td>{config}</td></tr>
<tr><td><b>Duration</b></td><td>{duration}</td></tr>
</table><br>
<b>Warning:</b> DEBUG may impact performance.
"""

    send_webhook("DEBUG Enabled", body.strip(), "F1C40F")
    log(f"Enabled {component} for {duration}")
    start_daemon(component)

    print(f"\nDEBUG enabled for component: {component}")
    print(f"Duration: {duration}\n")

# ================= DISABLE =================
def disable():
    component = select_component()
    config = COMPONENTS[component]["config"]

    if get_current_level(config) == "INFO":
        choice = input(f"\nDEBUG already disabled for {component}. Enable instead? (y/N): ").lower()
        if choice == "y":
            enable()
        return

    replace_level(config, "INFO")

    state_file = os.path.join(STATE_DIR, f"{component}.json")
    if os.path.exists(state_file):
        os.remove(state_file)

    body = f"""
<b>DEBUG logging has been DISABLED</b><br><br>
<table>
<tr><td><b>Component</b></td><td>{component}</td></tr>
<tr><td><b>Host</b></td><td>{get_hostname()}</td></tr>
<tr><td><b>User</b></td><td>{get_username()}</td></tr>
<tr><td><b>Config</b></td><td>{config}</td></tr>
<tr><td><b>Disabled at</b></td><td>{datetime.now():%F %T}</td></tr>
</table>
"""

    send_webhook("DEBUG Disabled", body.strip(), "2ECC71")
    log(f"Disabled {component}")

    print(f"\nDEBUG disabled for component: {component}\n")

# ================= ENTRY =================
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: script.py [enable|disable|status|daemon component]")
        sys.exit(1)

    if sys.argv[1] == "enable":
        enable()
    elif sys.argv[1] == "disable":
        disable()
    elif sys.argv[1] == "status":
        status()
    elif sys.argv[1] == "daemon" and len(sys.argv) == 3:
        daemon(sys.argv[2])
```
## 📜 Full Script (Bash)
```bash
#!/bin/bash

# ================= COMPONENT CONFIG =================
declare -A CONFIGS=(
  ["syscore"]="/home/syscore/cfg/logback.xml"
  ["bds"]="/home/bds/cfg/logback.xml"
)

# ================= PATHS =================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$SCRIPT_DIR/script_data"
STATE_DIR="$BASE_DIR/state"
PID_DIR="$BASE_DIR/pid"
LOG_DIR="$BASE_DIR/logs"
LOG_FILE="$LOG_DIR/log_toggle.log"

mkdir -p "$STATE_DIR" "$PID_DIR" "$LOG_DIR"

# ================= CONFIG =================
WEBHOOK_URL="https://my.webhook.office.com"

DEFAULT_END_TIME="18:00"
CHECK_INTERVAL=5

# ================= PROXY =================
USE_PROXY=false
HTTP_PROXY="http://10.10.2.200:8080"
HTTPS_PROXY="http://10.10.2.200:8080"

# ================= WEBHOOK SETTINGS =================
WEBHOOK_RETRIES=3
WEBHOOK_TIMEOUT=8

# ================= UTILITIES =================
log() {
  echo "[$(date '+%F %T')] $1" >> "$LOG_FILE"
}

backup_config() {
  local file="$1"
  local ts
  ts=$(date '+%F_%H-%M-%S')
  cp -p "$file" "$file.bak_$ts"
  log "Backup created: $file.bak_$ts"
}

format_duration() {
  local sec=$1
  (( sec < 0 )) && sec=0
  printf "%02dh %02dm" $((sec/3600)) $(((sec%3600)/60))
}

# ================= WEBHOOK WITH RETRY + LOGGING =================
send_webhook() {
  local title="$1"
  local body="$2"
  local color="$3"

  payload=$(cat <<EOF
{
  "@type":"MessageCard",
  "@context":"http://schema.org/extensions",
  "summary":"$title",
  "themeColor":"$color",
  "title":"$title",
  "text":"$body"
}
EOF
)

  if $USE_PROXY; then
    export http_proxy="$HTTP_PROXY"
    export https_proxy="$HTTPS_PROXY"
    export HTTP_PROXY="$HTTP_PROXY"
    export HTTPS_PROXY="$HTTPS_PROXY"
  else
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
  fi

  for ((i=1; i<=WEBHOOK_RETRIES; i++)); do
    http_code=$(curl -s -o /dev/null \
      --connect-timeout "$WEBHOOK_TIMEOUT" \
      --max-time "$WEBHOOK_TIMEOUT" \
      -w "%{http_code}" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "$WEBHOOK_URL")

    if [[ "$http_code" == "200" ]]; then
      log "Webhook success ($title)"
      return 0
    else
      log "Webhook failed ($title) attempt $i/$WEBHOOK_RETRIES HTTP=$http_code"
      sleep 2
    fi
  done

  log "Webhook permanently failed after $WEBHOOK_RETRIES attempts ($title)"
  return 1
}

# ================= LOG LEVEL =================
get_level() {
  grep -qi "DEBUG" "$1" && echo "DEBUG" || echo "INFO"
}

replace_to_debug() {
  backup_config "$1"
  sed -i \
    -e 's/level="INFO"/level="DEBUG"/gi' \
    -e 's/<level>INFO<\/level>/<level>DEBUG<\/level>/gi' "$1"
}

replace_to_info() {
  backup_config "$1"
  sed -i \
    -e 's/level="DEBUG"/level="INFO"/gi' \
    -e 's/<level>DEBUG<\/level>/<level>INFO<\/level>/gi' "$1"
}

# ================= COMPONENT SELECTION =================
select_component() {
  echo
  echo "Select component:"
  echo

  local names=()
  for k in "${!CONFIGS[@]}"; do names+=("$k"); done
  IFS=$'\n' names=($(sort <<<"${names[*]}")); unset IFS

  local i=1
  for name in "${names[@]}"; do
    printf "%d) %-10s -> %s\n" "$i" "$name" "${CONFIGS[$name]}"
    ((i++))
  done

  echo
  while true; do
    read -p "Enter choice (1-${#names[@]}): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice>=1 && choice<=${#names[@]} )); then
      COMPONENT="${names[$((choice-1))]}"
      CONFIG="${CONFIGS[$COMPONENT]}"
      return
    fi
    echo "Invalid selection."
  done
}

# ================= DAEMON =================
daemon() {
  component="$1"
  config="${CONFIGS[$component]}"
  state_file="$STATE_DIR/$component.state"
  pid_file="$PID_DIR/$component.pid"

  echo $$ > "$pid_file"
  log "Daemon started for $component (pid=$$)"

  while true; do
    if [[ -f "$state_file" ]]; then
      revert=$(cat "$state_file")
      now=$(date +%s)

      if (( now >= revert )); then
        replace_to_info "$config"

        send_webhook "DEBUG Disabled" \
"<b>DEBUG logging has been DISABLED (Auto)</b><br><br>
<table>
<tr><td><b>Component</b></td><td>$component</td></tr>
<tr><td><b>Host</b></td><td>$(hostname)</td></tr>
<tr><td><b>User</b></td><td>$(whoami)</td></tr>
<tr><td><b>Config</b></td><td>$config</td></tr>
<tr><td><b>Disabled at</b></td><td>$(date '+%F %T')</td></tr>
</table><br><i>Auto-disable executed by scheduler</i>" "2ECC71"

        log "Auto-disabled $component"
        rm -f "$state_file" "$pid_file"
        exit 0
      fi
    fi
    sleep "$CHECK_INTERVAL"
  done
}

start_daemon() {
  component="$1"
  pid_file="$PID_DIR/$component.pid"

  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    return
  fi

  nohup bash "$SCRIPT_DIR/$(basename "$0")" daemon "$component" >> "$LOG_FILE" 2>&1 &
}

# ================= ENABLE CORE =================
enable_selected() {
  COMPONENT="$1"
  CONFIG="${CONFIGS[$COMPONENT]}"
  state="$STATE_DIR/$COMPONENT.state"

  now=$(date +%s)
  today=$(date +%F)

  echo
  echo "=== Enable DEBUG ==="
  echo "Target : $COMPONENT -> $CONFIG"
  echo "Today  : $today"
  echo "Time   : $(date '+%T')"
  echo

  read -p "End time (HH:MM, default $DEFAULT_END_TIME): " et
  et=${et:-$DEFAULT_END_TIME}

  read -p "End date (YYYY-MM-DD, default $today): " ed
  ed=${ed:-$today}

  revert=$(date -d "$ed $et" +%s 2>/dev/null) || { echo "Invalid date/time"; return; }
  (( revert <= now )) && revert=$(date -d "$ed $et tomorrow" +%s)

  replace_to_debug "$CONFIG"
  echo "$revert" > "$state"
  start_daemon "$COMPONENT"

  dur=$(format_duration $((revert-now)))

  send_webhook "DEBUG Enabled" \
"<b>DEBUG logging has been ENABLED</b><br><br>
<table>
<tr><td><b>Component</b></td><td>$COMPONENT</td></tr>
<tr><td><b>Host</b></td><td>$(hostname)</td></tr>
<tr><td><b>User</b></td><td>$(whoami)</td></tr>
<tr><td><b>Config</b></td><td>$CONFIG</td></tr>
<tr><td><b>Duration</b></td><td>$dur</td></tr>
</table><br>
<b>Warning:</b> DEBUG may impact performance." "F1C40F"

  log "Enabled $COMPONENT for $dur"

  echo
  echo "DEBUG enabled for $COMPONENT"
  echo "Duration: $dur"
  echo
}

enable() {
  select_component

  if [[ "$(get_level "$CONFIG")" == "DEBUG" ]]; then
    echo "DEBUG already enabled for $COMPONENT"
    read -p "Disable instead? (y/N): " ans
    [[ "$ans" == "y" ]] && disable_direct "$COMPONENT"
    return
  fi

  enable_selected "$COMPONENT"
}

# ================= DISABLE =================
disable_direct() {
  COMPONENT="$1"
  CONFIG="${CONFIGS[$COMPONENT]}"
  pid_file="$PID_DIR/$COMPONENT.pid"

  replace_to_info "$CONFIG"
  rm -f "$STATE_DIR/$COMPONENT.state"

  # Properly stop daemon if running
  if [[ -f "$pid_file" ]]; then
    pid=$(cat "$pid_file")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid"
      log "Killed daemon for $COMPONENT (pid=$pid)"
    fi
    rm -f "$pid_file"
  fi

  send_webhook "DEBUG Disabled" \
"<b>DEBUG logging has been DISABLED</b><br><br>
<table>
<tr><td><b>Component</b></td><td>$COMPONENT</td></tr>
<tr><td><b>Host</b></td><td>$(hostname)</td></tr>
<tr><td><b>User</b></td><td>$(whoami)</td></tr>
<tr><td><b>Config</b></td><td>$CONFIG</td></tr>
<tr><td><b>Disabled at</b></td><td>$(date '+%F %T')</td></tr>
</table>" "2ECC71"

  log "Manually disabled $COMPONENT"

  echo
  echo "DEBUG disabled for $COMPONENT"
  echo
}

disable() {
  select_component

  if [[ "$(get_level "$CONFIG")" == "INFO" ]]; then
    echo "DEBUG already disabled for $COMPONENT"
    read -p "Enable instead? (y/N): " ans
    [[ "$ans" == "y" ]] && enable_selected "$COMPONENT"
    return
  fi

  disable_direct "$COMPONENT"
}

# ================= ENTRY =================
case "$1" in
  enable) enable ;;
  disable) disable ;;
  status)
    for c in "${!CONFIGS[@]}"; do
      state="$STATE_DIR/$c.state"
      lvl=$(get_level "${CONFIGS[$c]}")
      if [[ "$lvl" == "DEBUG" && -f "$state" ]]; then
        now=$(date +%s)
        revert=$(cat "$state")
        echo "$c : DEBUG (expires in $(format_duration $((revert-now)))) -> ${CONFIGS[$c]}"
      else
        echo "$c : $lvl -> ${CONFIGS[$c]}"
      fi
    done
    ;;
  daemon) daemon "$2" ;;
  *) echo "Usage: $0 enable|disable|status" ;;
esac
```
