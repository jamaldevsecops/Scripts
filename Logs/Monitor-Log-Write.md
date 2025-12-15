# 🚨 Log Traffic Monitor (Apache / App Logs)

## 🎯 Objective

This script monitors **application access logs** (Apache, Nginx, custom
app logs) and detects:

-   ✅ Service is running
-   ❌ But **no user traffic** is reaching it (no new log entries)

This solves a **real production blind spot** where: - Uptime checks
pass - Port checks pass - But users are blocked (LB / firewall / network
issue)

Alerts are sent to **Microsoft Teams** with: 
- 🔔 Severity (WARNING / CRITICAL)
- 🔁 Repeat interval (Alertmanager-style)
- 🛠 Per-log maintenance windows
- 🌐 Proxy auto-detection (portable)

------------------------------------------------------------------------

## ✨ Features

-   🧩 Per-log service name
-   ⏱ Silence (traffic-stuck) detection
-   🔴 WARNING → CRITICAL escalation
-   🔁 Repeat alerts (group interval)
-   ✅ Recovery notification
-   🕒 Per-log maintenance windows
-   🌍 Works with or without proxy
-   ⏰ Cron-safe

------------------------------------------------------------------------

## ⚙️ Configuration

### 🗂 LOGS (Per-log configuration)

``` python
LOGS = {
    "/var/log/apache2/access.log": {
        "service": "Apache",
        "maintenance_from": "10:20:00",
        "maintenance_to":   "10:25:00",
    },
    "/var/log/mylog": {
        "service": "MyLog",
        "maintenance_from": "10:26:00",
        "maintenance_to":   "10:30:00",
    },
}
```

  Field              Description
  ------------------ ----------------------------------
  log path           Absolute log file path
  service            Name shown in Teams alert
  maintenance_from   Maintenance start (24h HH:MM:SS)
  maintenance_to     Maintenance end (24h HH:MM:SS)

🛑 During maintenance: - Alerts are suppressed - State is preserved -
Alerts resume automatically after window

------------------------------------------------------------------------

### ⏱ LOG_MONITORING_THRESHOLD

``` python
LOG_MONITORING_THRESHOLD = 60  # seconds
```

⏰ If **no new log entry** appears for this duration → alert fires.

------------------------------------------------------------------------

### 🔁 GROUP_INTERVAL

``` python
GROUP_INTERVAL = 120  # seconds
```

🔕 While issue persists: - Alert repeats every `GROUP_INTERVAL` -
Prevents alert flooding

------------------------------------------------------------------------

### 🔴 CRITICAL_MULTIPLIER

``` python
CRITICAL_MULTIPLIER = 2
```

Severity logic: - ⚠️ WARNING → idle ≥ threshold - 🔴 CRITICAL → idle ≥
threshold × multiplier

------------------------------------------------------------------------

## 🌐 Proxy Configuration (Portable)

The script **does not hardcode proxy**.

It automatically detects proxy from environment variables:

-   `HTTP_PROXY`
-   `HTTPS_PROXY`
-   `NO_PROXY`

### ✅ Recommended (System-wide)

Edit `/etc/environment`:

``` bash
HTTP_PROXY=http://192.168.20.126:8080
HTTPS_PROXY=http://192.168.20.126:8080
NO_PROXY=localhost,127.0.0.1
```

🔄 Logout / reboot after setting.

------------------------------------------------------------------------

### 🕒 Cron-specific Proxy (Alternative)

``` bash
crontab -e
```

``` text
HTTP_PROXY=http://192.168.20.126:8080
HTTPS_PROXY=http://192.168.20.126:8080
NO_PROXY=localhost,127.0.0.1

* * * * * python3 /root/log_traffic_monitor.py
```

------------------------------------------------------------------------

## ⏰ Cron Setup

``` bash
* * * * * python3 /root/log_traffic_monitor.py
```

Runs every minute.

------------------------------------------------------------------------

## 🧪 Example Teams Alert

    🔴 Apache Log Traffic Stuck (CRITICAL)

    🖥️ Server: server01
    📄 Log File: /var/log/apache2/access.log
    ⏱️ Idle Time: 00:01:15

    🧠 Meaning:
    No user traffic reached Apache.
    This alert repeats every 2 minutes while the issue persists.

------------------------------------------------------------------------

## 📄 Local Debug Log

    /tmp/log_traffic_monitor.log

------------------------------------------------------------------------

## 🧩 Full Script

``` python
#!/usr/bin/env python3

import os
import time
import requests
from datetime import datetime

# ========================
# CONFIGURATION
# ========================

LOGS = {
    "/var/log/apache2/access.log": {
        "service": "Apache",
        "maintenance_from": "10:20:00",
        "maintenance_to":   "10:25:00",
    },
    "/var/log/mylog": {
        "service": "MyLog",
        "maintenance_from": "10:26:00",
        "maintenance_to":   "10:30:00",
    },
}

LOG_MONITORING_THRESHOLD = 60      # seconds
GROUP_INTERVAL = 120               # seconds
CRITICAL_MULTIPLIER = 2

STATE_DIR = "/var/run/log_monitor"
LOCAL_LOG = "/tmp/log_traffic_monitor.log"

WEBHOOK_URL = "https://nagadbd.webhook.office.com/webhookb2/5b4e2485-c0f8-44f3-9c8f-5425f9eb2e33@1fdbc307-1c9d-4e67-9cc6-89ac4325a317/IncomingWebhook/982947ad6b3141fb88e0686cd40fed6d/76525452-edda-408d-b048-8a50f2297a81/V2rLNkO-UpUNNV3sUjzRjal9cS9ZOb2N0Mu7enAC6jqd01"


# ========================
# AUTO-DETECT PROXY (PORTABLE)
# ========================

PROXIES = None  # default: no proxy (don’t use a proxy unless one is explicitly provided)

http_proxy = os.environ.get("HTTP_PROXY") or os.environ.get("http_proxy")
https_proxy = os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy")

if http_proxy or https_proxy:
    PROXIES = {}
    if http_proxy:
        PROXIES["http"] = http_proxy
    if https_proxy:
        PROXIES["https"] = https_proxy


HOSTNAME = os.uname().nodename
os.makedirs(STATE_DIR, exist_ok=True)

# ========================
# UTILITIES
# ========================

def log_local(msg):
    with open(LOCAL_LOG, "a") as f:
        f.write(f"{datetime.now():%F %T} | {msg}\n")

def format_duration(sec):
    return f"{sec//3600:02}:{(sec%3600)//60:02}:{sec%60:02}"

def send_webhook(message, log_path):
    try:
        r = requests.post(
            WEBHOOK_URL,
            json={"text": message},
            timeout=5,
            proxies=PROXIES   # ← auto proxy / no proxy
        )
        log_local(
            f"WEBHOOK RESPONSE | log={log_path} | http={r.status_code} | proxy={'yes' if PROXIES else 'no'}"
        )
        return r.status_code in (200, 202)
    except Exception as e:
        log_local(
            f"WEBHOOK ERROR | log={log_path} | proxy={'yes' if PROXIES else 'no'} | error={e}"
        )
        return False

def in_maintenance_window(start_str, end_str):
    now = datetime.now().time()
    start = datetime.strptime(start_str, "%H:%M:%S").time()
    end = datetime.strptime(end_str, "%H:%M:%S").time()

    if start < end:
        return start <= now <= end

    return now >= start or now <= end

# ========================
# MAIN
# ========================

log_local(
    f"SCRIPT STARTED | proxy={'enabled' if PROXIES else 'disabled'}"
)

now = int(time.time())

for log_path, cfg in LOGS.items():

    SERVICE_NAME = cfg["service"]
    MAINT_FROM = cfg["maintenance_from"]
    MAINT_TO = cfg["maintenance_to"]

    if not os.path.isfile(log_path):
        log_local(f"SKIP | log not found: {log_path}")
        continue

    # ========================
    # MAINTENANCE CHECK
    # ========================
    if in_maintenance_window(MAINT_FROM, MAINT_TO):
        log_local(
            f"MAINTENANCE WINDOW ACTIVE | service={SERVICE_NAME} | log={log_path} | alerts suppressed"
        )
        continue

    log_id = log_path.replace("/", "_")
    state_file = f"{STATE_DIR}/{log_id}.state"
    last_alert_file = f"{STATE_DIR}/{log_id}.last_alert"

    state = "OK"
    if os.path.isfile(state_file):
        state = open(state_file).read().strip()

    last_alert_time = 0
    if os.path.isfile(last_alert_file):
        last_alert_time = int(open(last_alert_file).read().strip())

    last_write = int(os.path.getmtime(log_path))
    idle_time = now - last_write
    idle_fmt = format_duration(idle_time)

    # ========================
    # SEVERITY
    # ========================
    if idle_time >= LOG_MONITORING_THRESHOLD * CRITICAL_MULTIPLIER:
        severity = "CRITICAL"
        emoji = "🔴"
    elif idle_time >= LOG_MONITORING_THRESHOLD:
        severity = "WARNING"
        emoji = "⚠️"
    else:
        severity = "OK"

    log_local(
        f"CHECK | service={SERVICE_NAME} | idle={idle_time}s | severity={severity} | state={state}"
    )

    # ========================
    # ALERT / REMINDER
    # ========================
    if idle_time >= LOG_MONITORING_THRESHOLD:

        should_alert = (
            state == "OK" or
            (now - last_alert_time) >= GROUP_INTERVAL
        )

        if should_alert:
            message = (
                f"{emoji} **{SERVICE_NAME} Log Traffic Stuck** ({severity})\n\n"
                f"🖥️ Server: {HOSTNAME}\n\n"
                f"📄 Log File: {log_path}\n\n"
                f"⏱️ Idle Time: {idle_fmt}\n\n"
                f"🧠 Meaning:\n"
                f"No user traffic reached {SERVICE_NAME}.\n"
                f"This alert repeats every {GROUP_INTERVAL//60} minutes while the issue persists."
            )

            if send_webhook(message, log_path):
                open(state_file, "w").write("ALERTED")
                open(last_alert_file, "w").write(str(now))
                log_local(f"ALERT SENT | service={SERVICE_NAME} | severity={severity}")

        else:
            log_local(f"ALERT SUPPRESSED | within GROUP_INTERVAL | service={SERVICE_NAME}")

    # ========================
    # RECOVERY
    # ========================
    else:
        if state == "ALERTED":
            message = (
                f"✅ **{SERVICE_NAME} Log Traffic Recovered**\n\n"
                f"🖥️ Server: {HOSTNAME}\n\n"
                f"📄 Log File: {log_path}\n\n"
                f"🎉 Traffic has resumed."
            )

            if send_webhook(message, log_path):
                open(state_file, "w").write("OK")
                open(last_alert_file, "w").write("0")
                log_local(f"RECOVERY SENT | service={SERVICE_NAME}")

log_local("SCRIPT FINISHED")
```
