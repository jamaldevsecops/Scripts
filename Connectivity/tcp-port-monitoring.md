
## 📡 TCP Port Monitoring Script

This script performs periodic **TCP connectivity checks** for multiple configured services (MNO endpoints) by attempting to establish a socket connection to specified hosts and ports.

It determines whether each service is:
- 🟢 **UP** (reachable)  
- 🔴 **DOWN** (unreachable)

🚨 The script includes **alerting with suppression**, ensuring notifications are only sent on state changes or after a defined interval to avoid alert flooding.

📢 When an issue is detected, it sends a **formatted alert to Microsoft Teams** via webhook (through a forward proxy if configured).

🗂️ It also maintains **state files** for tracking previous statuses and uses **rotating logs** for efficient logging and troubleshooting.

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import time
import requests
import socket
import logging
from logging.handlers import RotatingFileHandler
from datetime import datetime

# ========================
# CONFIGURATION
# ========================

TARGETS = {
    "GP": {
        "host": "grameenphone.com",
        "port": 443,
        "timeout": 5
    },
    "Banglalink": {
        "host": "banglalink.net",
        "port": 443,
        "timeout": 5
    },
    "Teletalk": {
        "host": "teletalk.com.bd",
        "port": 443,
        "timeout": 5
    },
    "Robi": {
        "host": "robi.com.bd",
        "port": 443,
        "timeout": 5
    }    
}

ALERT_INTERVAL = 120

WEBHOOK_URL = "YOUR_WEBHOOK_URL"

# Proxy only for webhook
WEBHOOK_PROXIES = {
    "http": "http://x.x.x:8080",
    "https": "http://x..x.x:8080"
}

# ========================
# LOCAL DIRECTORY SETUP
# ========================

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

STATE_DIR = os.path.join(SCRIPT_DIR, "STATE")
LOG_DIR = os.path.join(SCRIPT_DIR, "LOGS")

os.makedirs(STATE_DIR, exist_ok=True)
os.makedirs(LOG_DIR, exist_ok=True)

HOSTNAME = socket.gethostname()

# ========================
# LOGGING (ROTATION)
# ========================

LOG_FILE = os.path.join(LOG_DIR, "tcp_monitor.log")

logger = logging.getLogger("tcp_monitor")
logger.setLevel(logging.INFO)

handler = RotatingFileHandler(
    LOG_FILE,
    maxBytes=5 * 1024 * 1024,
    backupCount=5
)

formatter = logging.Formatter(
    "%(asctime)s | %(levelname)s | %(message)s",
    "%Y-%m-%d %H:%M:%S"
)

handler.setFormatter(formatter)
logger.addHandler(handler)

console = logging.StreamHandler()
console.setFormatter(formatter)
logger.addHandler(console)


def log(msg):
    logger.info(msg)

# ========================
# TCP CHECK
# ========================

def check_tcp(host, port, timeout):
    try:
        start = time.time()
        sock = socket.create_connection((host, port), timeout)
        sock.close()
        response_time = time.time() - start
        return "UP", response_time
    except Exception:
        return "DOWN", 0

# ========================
# TEAMS FORMAT
# ========================

def format_status(status):
    if status == "DOWN":
        return '<font color="red"><b>DOWN</b></font>'
    else:
        return '<font color="green"><b>UP</b></font>'


def send_teams_card(results):
    try:
        table_lines = []

        table_lines.append("| **Service** | **Status** | **Response** | **Host** | **Port** |")
        table_lines.append("|:--|:--|:--|:--|:--|")

        for r in results:
            response_str = "{:.2f}s".format(r["response"])
            status_display = format_status(r["status"])

            table_lines.append(
                f"| {r['name']} | {status_display} | {response_str} | {r['host']} | {r['port']} |"
            )

        table = "\n".join(table_lines)

        down_services = [r['name'] for r in results if r['status'] == 'DOWN']

        action_block = ""
        if down_services:
            action_block = (
                f"\n\n<font color='red'><b>Action Required (SOC):</b></font>  \n"
                f"- Verify network connectivity.  \n"
                f"- If connectivity is confirmed and the issue persists, please coordinate with ({', '.join(down_services)})"
            )

        payload = {
            "@type": "MessageCard",
            "@context": "http://schema.org/extensions",
            "summary": "TCP Monitoring",
            "themeColor": "FF0000" if down_services else "00FF00",
            "title": "MNO Service Monitoring Summary",
            "text": (
                f"**Server:** {HOSTNAME}  \n"
                f"**Time:** {datetime.now():%F %T}  \n\n"
                f"{table}"
                f"{action_block}"
            )
        }

        try:
            r = requests.post(
                WEBHOOK_URL,
                json=payload,
                timeout=5,
                proxies=WEBHOOK_PROXIES
            )

            log(f"Webhook response code: {r.status_code}")

            if r.status_code not in (200, 202):
                log(f"Webhook failed: {r.text}")

            return r.status_code in (200, 202)

        except Exception as e:
            log(f"WEBHOOK ERROR (proxy/network): {e}")
            return False

    except Exception as e:
        log(f"WEBHOOK BUILD ERROR: {e}")
        return False

# ========================
# MAIN
# ========================

log("TCP Monitor started")

now = int(time.time())
results = []
send_required = False

for name, cfg in TARGETS.items():
    host = cfg["host"]
    port = cfg["port"]
    timeout = cfg["timeout"]

    state_file = os.path.join(STATE_DIR, f"{name}.state")
    alert_file = os.path.join(STATE_DIR, f"{name}.last_alert")

    state = "UP"
    if os.path.isfile(state_file):
        try:
            state = open(state_file).read().strip()
        except:
            pass

    last_alert = 0
    if os.path.isfile(alert_file):
        try:
            last_alert = int(open(alert_file).read().strip())
        except:
            pass

    status, response_time = check_tcp(host, port, timeout)

    time_since_last = now - last_alert if last_alert else 0

    log(f"{name} | TCP status={status} | host={host} | port={port} | last_alert={time_since_last}s")

    if status == "DOWN":

        if state == "UP":
            log(f"{name} -> ALERT REQUIRED (first detection)")
            send_required = True
            open(state_file, "w").write("ALERTED")
            open(alert_file, "w").write(str(now))

        elif time_since_last >= ALERT_INTERVAL:
            log(f"{name} -> ALERT REQUIRED (interval exceeded)")
            send_required = True
            open(state_file, "w").write("ALERTED")
            open(alert_file, "w").write(str(now))

        else:
            log(f"{name} -> ALERT SUPPRESSED")

    else:
        if state == "ALERTED":
            log(f"{name} -> RECOVERY DETECTED")
            send_required = True
            open(state_file, "w").write("UP")
            open(alert_file, "w").write("0")
        else:
            log(f"{name} -> NO ACTION")

    results.append({
        "name": name,
        "host": host,
        "port": port,
        "status": status,
        "response": response_time
    })

# Sort: DOWN first
priority = {"DOWN": 0, "UP": 1}
results.sort(key=lambda x: priority.get(x["status"], 2))

if send_required:
    log("FINAL DECISION -> Sending Teams alert")
    if send_teams_card(results):
        log("TEAMS ALERT SENT")
    else:
        log("TEAMS ALERT FAILED")
else:
    log("FINAL DECISION -> No alert needed")

log("TCP Monitor finished")
```
