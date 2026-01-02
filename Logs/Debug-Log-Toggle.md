# 🐞 Debug Logging Toggle Script (Python)

## 📌 Purpose

This script is used to **temporarily enable DEBUG logging** in a Java application's `logback.xml` file and **automatically revert it back to INFO** after a specified date and time.

It is designed for **production troubleshooting**, ensuring that DEBUG logging:
- Is enabled only for a limited period
- Automatically rolls back to avoid performance impact
- Can be manually disabled at any time
- Notifies teams via webhook (Microsoft Teams / Office Webhook)

The script is tested and works on:
- **RHEL**
- **Ubuntu**

---

## 🎯 Key Features

- Enable DEBUG logging until a specific date & time  
- Automatic rollback (DEBUG → INFO) via background daemon  
- Manual rollback command available at any time  
- Webhook notifications on:
  - DEBUG enabled
  - DEBUG disabled (automatic or manual)
- Explicit **proxy on/off switch inside the script**
- Emoji-safe (UTF-8 clean, RHEL compatible)
- No cron or external scheduler required

---

## ▶️ Usage

### Enable DEBUG logging

```bash
python3 debug_logging.py enable
```

You will be prompted for:
- End time (HH:MM)
- End date (YYYY-MM-DD)

---

### Disable DEBUG logging manually

```bash
python3 debug_logging.py disable
```

---

## 🌐 Proxy Configuration

Proxy behavior is controlled **inside the script**.

```python
USE_PROXY = True   # Set to False to disable proxy
```

```python
PROXIES = {
    "http":  "http://10.10.10.1:8080",
    "https": "http://10.10.10.1:8080",
}
```

---

## 📂 Files Used

| Path | Purpose |
|---|---|
| /home/syscore/cfg/logback.xml | Target Logback configuration |
| /var/run/debug_toggle/state.json | Rollback schedule |
| /var/run/debug_toggle/daemon.pid | Daemon PID |
| /var/log/debug_toggle/debug_toggle.log | Local audit log |

---

## 📜 Full Script

```python
#!/usr/bin/env python3
import os
import sys
import json
import time
import re
import shutil
import urllib.request
import subprocess
from datetime import datetime, timedelta

# ================= CONFIG =================
CONFIG_FILE = "/home/syscore/cfg/logback.xml"
STATE_FILE  = "/var/lib/debug_toggle/state.json"
LOG_FILE    = "/var/log/debug_toggle/log_toggle.log"
PID_FILE    = "/var/run/debug_toggle/daemon.pid"

WEBHOOK_URL = "https://nagadbd.webhook.office.com/webhookb2"

DEFAULT_END_TIME = "18:00"
CHECK_INTERVAL = 5  # seconds

LEVEL_REGEX = re.compile(
    r'(<(root|logger)[^>]*level=")[A-Z]+(")',
    re.IGNORECASE
)

# ================= PROXY CONFIG =================
# 🔁 Set USE_PROXY = True to enable proxy
USE_PROXY = False

PROXY_CONFIG = {
    "http":  "http://10.10.10.1:8080",
    "https": "http://10.10.10.1:8080",
}
# For authenticated proxy:
# "http":  "http://user:password@10.10.10.1:8080"
# "https": "http://user:password@10.10.10.1:8080"

# ================= UTIL =================
def ensure_dirs():
    for path in (STATE_FILE, LOG_FILE, PID_FILE):
        os.makedirs(os.path.dirname(path), exist_ok=True)


def log(msg):
    ensure_dirs()
    with open(LOG_FILE, "a") as f:
        f.write(f"[{datetime.now():%F %T}] {msg}\n")


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

    # -------- Proxy handling (script-controlled) --------
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


def replace_level(level):
    with open(CONFIG_FILE) as f:
        content = f.read()

    updated, count = LEVEL_REGEX.subn(rf"\1{level}\3", content)
    if count == 0:
        raise RuntimeError("No logback level attribute found")

    with open(CONFIG_FILE, "w") as f:
        f.write(updated)

# ================= DAEMON =================
def daemon():
    ensure_dirs()
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    log("Daemon started")

    while True:
        if os.path.exists(STATE_FILE):
            with open(STATE_FILE) as f:
                state = json.load(f)

            if datetime.now() >= datetime.fromisoformat(state["revert_at"]):
                replace_level("INFO")
                os.remove(STATE_FILE)

                log("DEBUG auto-disabled")

                send_webhook(
                    "✅ DEBUG Disabled",
                    f"🟢 **DEBUG logging has been DISABLED**\n\n"
                    f"📄 **Config:** `{CONFIG_FILE}`\n\n"
                    f"⏱ **Disabled at:** `{datetime.now():%F %T}`\n\n"
                    f"✅ **System logging is back to normal.**",
                    "2ECC71"
                )

                os.remove(PID_FILE)
                sys.exit(0)

        time.sleep(CHECK_INTERVAL)


def daemon_running():
    if not os.path.exists(PID_FILE):
        return False
    try:
        pid = int(open(PID_FILE).read())
        os.kill(pid, 0)
        return True
    except Exception:
        return False


def start_daemon():
    if daemon_running():
        return
    subprocess.Popen(
        [sys.executable, __file__, "daemon"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True
    )

# ================= ENABLE =================
def enable():
    now = datetime.now()

    print("\n=== 🐞 DEBUG Enable ===")
    print(f"📅 Today : {now:%F}")
    print(f"⏰ Time  : {now:%T}\n")

    end_time = input(f"⏰ End time (HH:MM, default {DEFAULT_END_TIME}): ").strip() or DEFAULT_END_TIME
    end_date = input(f"🗓 End date (YYYY-MM-DD, default {now:%F}): ").strip() or now.strftime("%F")

    try:
        revert_at = datetime.strptime(f"{end_date} {end_time}", "%Y-%m-%d %H:%M")
    except ValueError:
        print("❌ Invalid date/time format")
        sys.exit(1)

    if revert_at <= now:
        revert_at += timedelta(days=1)

    ensure_dirs()
    shutil.copy2(CONFIG_FILE, f"{CONFIG_FILE}.bak_{now:%F_%H-%M-%S}")
    replace_level("DEBUG")

    with open(STATE_FILE, "w") as f:
        json.dump({"revert_at": revert_at.isoformat()}, f)

    log(f"DEBUG enabled until {revert_at}")

    send_webhook(
        "🐞 DEBUG Enabled",
        f"🟡 **DEBUG logging has been ENABLED**\n\n"
        f"📄 **Config:** `{CONFIG_FILE}`\n\n"
        f"⏳ **Revert at:** `{revert_at:%F %T}`\n\n"
        f"⚠️ **DEBUG may impact performance.**",
        "F1C40F"
    )

    start_daemon()

    print("\n✅ DEBUG enabled successfully")
    print(f"⏳ Scheduled revert at : {revert_at:%F %T}")
    print("ℹ️ Auto-disable is active in background\n")

# ================= DISABLE =================
def disable():
    if not os.path.exists(STATE_FILE):
        print("ℹ️ DEBUG already OFF")
        return

    replace_level("INFO")
    os.remove(STATE_FILE)

    log("DEBUG manually disabled")

    send_webhook(
        "✅ DEBUG Disabled",
        f"🟢 **DEBUG logging has been DISABLED**\n\n"
        f"📄 **Config:** `{CONFIG_FILE}`\n\n"
        f"⏱ **Disabled at:** `{datetime.now():%F %T}`\n\n"
        f"✅ **System logging is back to normal.**",
        "2ECC71"
    )

    print("✅ DEBUG disabled")

# ================= ENTRY =================
if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: log_toggle.py [enable|disable]")
        sys.exit(1)

    if sys.argv[1] == "enable":
        enable()
    elif sys.argv[1] == "disable":
        disable()
    elif sys.argv[1] == "daemon":
        daemon()
```

---

## ✅ Summary

This script provides a **safe, auditable, and production-ready** way to temporarily enable DEBUG logging with automatic rollback and notification support.
