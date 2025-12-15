# 🚨 Log Traffic Monitor (Apache / App Logs)

## 🎯 Objective

This script monitors **application access logs** (Apache, Nginx, custom
app logs) and detects:

-   ✅ Service is running
-   ❌ But **no user traffic** is reaching it (no new log entries)

This solves a **real production blind spot** where: - Uptime checks
pass - Port checks pass - But users are blocked (LB / firewall / network
issue)

Alerts are sent to **Microsoft Teams** with: - 🔔 Severity (WARNING /
CRITICAL) - 🔁 Repeat interval (Alertmanager-style) - 🛠 Per-log
maintenance windows - 🌐 Proxy auto-detection (portable)

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

LOG_MONITORING_THRESHOLD = 60
GROUP_INTERVAL = 120
CRITICAL_MULTIPLIER = 2

STATE_DIR = "/var/run/log_monitor"
LOCAL_LOG = "/tmp/log_traffic_monitor.log"

WEBHOOK_URL = "<YOUR WEBHOOK URL>"

# ========================
# AUTO-DETECT PROXY
# ========================

PROXIES = None
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

def log_local(msg):
    with open(LOCAL_LOG, "a") as f:
        f.write(f"{datetime.now():%F %T} | {msg}\n")

def format_duration(sec):
    return f"{sec//3600:02}:{(sec%3600)//60:02}:{sec%60:02}"

def send_webhook(message, log_path):
    r = requests.post(WEBHOOK_URL, json={"text": message}, timeout=5, proxies=PROXIES)
    return r.status_code in (200, 202)
```
