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

## 📜 Full Script
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
