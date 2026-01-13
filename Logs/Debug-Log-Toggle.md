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
    "syscore": {
        "config": "/home/syscore/cfg/logback.xml"
    },
    "bds": {
        "config": "/var/log/bds/xyz/logback.xml"
    }
}

# ================= PATHS =================
BASE_DIR   = "/var/lib/debug_toggle"
STATE_DIR  = f"{BASE_DIR}/state"
LOG_FILE   = "/var/log/debug_toggle/log_toggle.log"
PID_DIR    = f"{BASE_DIR}/pid"

WEBHOOK_URL = "https://my.webhook.office.com"

DEFAULT_END_TIME = "18:00"
CHECK_INTERVAL = 5  # seconds

# ================= PROXY CONFIG =================
USE_PROXY = False

PROXY_CONFIG = {
    "http":  "http://10.10.10.200:8080",
    "https": "http://10.10.10.200:8080",
}

# ================= UTILITIES =================
def ensure_dirs():
    for d in (STATE_DIR, os.path.dirname(LOG_FILE), PID_DIR):
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
    total_seconds = int(delta.total_seconds())
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
            print("Invalid time format.")
        except KeyboardInterrupt:
            print("\nCancelled.")
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
            print("Invalid date format.")
        except KeyboardInterrupt:
            print("\nCancelled.")
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
        except ValueError:
            print("Invalid selection.")
        except KeyboardInterrupt:
            print("\nCancelled.")
            sys.exit(130)


# ================= DAEMON =================
def daemon(component):
    ensure_dirs()
    pid_file = f"{PID_DIR}/{component}.pid"
    state_file = f"{STATE_DIR}/{component}.json"

    with open(pid_file, "w") as f:
        f.write(str(os.getpid()))

    while True:
        try:
            if os.path.exists(state_file):
                with open(state_file) as f:
                    state = json.load(f)

                if datetime.now() >= datetime.fromisoformat(state["revert_at"]):
                    replace_level(state["config"], "INFO")
                    os.remove(state_file)

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
                    os.remove(pid_file)
                    sys.exit(0)

        except Exception as e:
            log(f"{component}: daemon error: {e}")

        time.sleep(CHECK_INTERVAL)


def start_daemon(component):
    subprocess.Popen(
        [sys.executable, __file__, "daemon", component],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True
    )


# ================= ENABLE =================
def enable():
    component = select_component()
    config = COMPONENTS[component]["config"]

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

    state_file = f"{STATE_DIR}/{component}.json"
    with open(state_file, "w") as f:
        json.dump({
            "revert_at": revert_at.isoformat(),
            "config": config
        }, f)

    hostname = get_hostname()
    username = get_username()
    duration = format_duration(revert_at - now)

    body = f"""
<b>DEBUG logging has been ENABLED</b><br><br>
<table>
<tr><td><b>Component</b></td><td>{component}</td></tr>
<tr><td><b>Host</b></td><td>{hostname}</td></tr>
<tr><td><b>User</b></td><td>{username}</td></tr>
<tr><td><b>Config</b></td><td>{config}</td></tr>
<tr><td><b>Duration</b></td><td>{duration}</td></tr>
</table><br>
<b>Warning:</b> DEBUG may impact performance.
"""

    send_webhook("DEBUG Enabled", body.strip(), "F1C40F")
    start_daemon(component)

    print(f"\nDEBUG enabled for component: {component}")
    print(f"Duration: {duration}\n")


# ================= DISABLE =================
def disable():
    component = select_component()
    config = COMPONENTS[component]["config"]

    replace_level(config, "INFO")

    state_file = f"{STATE_DIR}/{component}.json"
    if os.path.exists(state_file):
        os.remove(state_file)

    hostname = get_hostname()
    username = get_username()

    body = f"""
<b>DEBUG logging has been DISABLED</b><br><br>
<table>
<tr><td><b>Component</b></td><td>{component}</td></tr>
<tr><td><b>Host</b></td><td>{hostname}</td></tr>
<tr><td><b>User</b></td><td>{username}</td></tr>
<tr><td><b>Config</b></td><td>{config}</td></tr>
<tr><td><b>Disabled at</b></td><td>{datetime.now():%F %T}</td></tr>
</table>
"""

    send_webhook("DEBUG Disabled", body.strip(), "2ECC71")
    print(f"\nDEBUG disabled for component: {component}\n")


# ================= ENTRY =================
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: script.py [enable|disable|daemon component]")
        sys.exit(1)

    if sys.argv[1] == "enable":
        enable()
    elif sys.argv[1] == "disable":
        disable()
    elif sys.argv[1] == "daemon" and len(sys.argv) == 3:
        daemon(sys.argv[2])
```

---

## ✅ Summary

This script provides a **safe, auditable, and production-ready** way to temporarily enable DEBUG logging with automatic rollback and notification support.
