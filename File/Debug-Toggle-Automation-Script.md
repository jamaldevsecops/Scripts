# Debug Toggle Automation Script

## Overview
This script enables DEBUG mode in `/home/syscore/cfg/logback.xml` until a specified time and date, 
then automatically reverts it back to INFO. It runs in the background and continues even if the terminal closes.

---

## 📋 Features
- Enables DEBUG until a given date and time. 
- Automatically reverts to INFO after the specified time. 
- Detects if DEBUG is already active.
- Detects if another background toggle is already running.
- Works if the terminal is closed.
- Designed for non-root users (with simple permission setup).

---

## ⚙️ Setup Instructions

### 1. Save Script
Create the script file:

```bash
sudo nano /usr/local/bin/debug_toggle.sh
```

Paste the full script (see below), then make it executable:

```bash
sudo chmod +x /usr/local/bin/debug_toggle.sh
```

---

### 2. Adjust File Permissions (for non-root users)
To allow the `syscore` user to run this safely:

```bash
sudo mkdir -p /var/log/debug_toggle
sudo mkdir -p /var/run/debug_toggle
sudo chown syscore:syscore /var/log/debug_toggle /var/run/debug_toggle
sudo chown syscore:syscore /home/syscore/cfg/logback.xml
```

Edit script paths:

```bash
LOG_FILE="/var/log/debug_toggle/logback_toggle.log"
PID_FILE="/var/run/debug_toggle/debug_toggle.pid"
NOHUP_OUT="/var/log/debug_toggle/debug_toggle.out"
```

---

## 🚀 Usage

Run interactively:

```bash
bash /usr/local/bin/debug_toggle.sh
```

Example run:

```
=== DEBUG Toggle Script ===
Enter end time (HH:MM, default 15:00): 16
Enter end date (YYYY-MM-DD, default today):
[2025-10-29 14:10:32] ✅ DEBUG enabled (will revert at 2025-10-29 16:00).
[2025-10-29 14:10:32] Running in background (PID 41092) for ~109 minutes.
✅ You can safely close the terminal now.
```

---

## 🧠 Script Code

```bash
#!/bin/bash
CONFIG_FILE="/home/syscore/cfg/logback.xml"
LOG_FILE="/var/log/debug_toggle/logback_toggle.log"
PID_FILE="/var/run/debug_toggle/debug_toggle.pid"
NOHUP_OUT="/var/log/debug_toggle/debug_toggle.out"
DEFAULT_END_TIME="15:00"

log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

is_debug_active() {
    grep -q "DEBUG" "$CONFIG_FILE"
}

if [ -f "$PID_FILE" ] && ps -p "$(cat "$PID_FILE")" > /dev/null 2>&1; then
    log "⚠️  Another debug toggle process (PID $(cat "$PID_FILE")) is already running."
    exit 1
fi

if is_debug_active; then
    log "ℹ️  DEBUG mode already active. Nothing to enable."
    exit 0
fi

if [ -t 0 ]; then
    echo "=== DEBUG Toggle Script ==="
    read -p "Enter end time (HH:MM, default ${DEFAULT_END_TIME}): " END_TIME
    END_TIME=${END_TIME:-$DEFAULT_END_TIME}
    if [[ $END_TIME =~ ^[0-9]{1,2}$ ]]; then
        END_TIME="${END_TIME}:00"
    fi
    read -p "Enter end date (YYYY-MM-DD, default today): " END_DATE
    END_DATE=${END_DATE:-$(date +%F)}
else
    END_TIME=$DEFAULT_END_TIME
    END_DATE=$(date +%F)
fi

CURRENT_TIME=$(date +%s)
END_EPOCH=$(date -d "$END_DATE $END_TIME" +%s 2>/dev/null)

if [[ -z "$END_EPOCH" ]]; then
    log "❌ Invalid date or time format. Use YYYY-MM-DD and HH:MM."
    exit 1
fi

if [[ $END_EPOCH -le $CURRENT_TIME ]]; then
    log "⚠️  Specified time already passed. Scheduling for tomorrow at $END_TIME."
    END_DATE=$(date -d "tomorrow" +%F)
    END_EPOCH=$(date -d "$END_DATE $END_TIME" +%s)
fi

SLEEP_DURATION=$((END_EPOCH - CURRENT_TIME))

cp "$CONFIG_FILE" "$CONFIG_FILE.bak_$(date +%F_%H-%M-%S)"
sed -i 's/INFO/DEBUG/g' "$CONFIG_FILE"
log "✅ DEBUG enabled (will revert at $END_DATE $END_TIME)."
echo $$ > "$PID_FILE"

nohup bash -c "
    sleep $SLEEP_DURATION
    sed -i 's/DEBUG/INFO/g' '$CONFIG_FILE'
    echo "[\$(date '+%F %T')] ✅ DEBUG automatically disabled." >> '$LOG_FILE'
    rm -f '$PID_FILE'
" > "$NOHUP_OUT" 2>&1 &

log "Running in background (PID $!) for ~$((SLEEP_DURATION / 60)) minutes."
echo "✅ You can safely close the terminal now."
```

---

## 🧩 Optional — Sudo Restriction
If you prefer to keep config file root-owned but still allow the user to run it:

```bash
sudo visudo
```

Add:
```
syscore ALL=(ALL) NOPASSWD: /usr/local/bin/debug_toggle.sh
```

Then the user runs:
```bash
sudo /usr/local/bin/debug_toggle.sh
```

---

## ✅ Summary
| Feature | Supported |
|----------|------------|
| Interactive time/date input | ✅ |
| Background execution | ✅ |
| Works if terminal closes | ✅ |
| Duplicate prevention | ✅ |
| Non-root operation (with setup) | ✅ |
