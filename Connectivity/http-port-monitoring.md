## 📡 TCP Port Monitoring Script

This script performs periodic **TCP connectivity checks** for multiple configured services (MNO endpoints) by attempting to establish a socket connection to specified hosts and ports.

It determines whether each service is:
- 🟢 **UP** (reachable)  
- 🔴 **DOWN** (unreachable)

🚨 The script includes **alerting with suppression**, ensuring notifications are only sent on state changes or after a defined interval to avoid alert flooding.

📢 When an issue is detected, it sends a **formatted alert to Microsoft Teams** via webhook (through a forward proxy if configured).

🗂️ It also maintains **state files** for tracking previous statuses and uses **rotating logs** for efficient logging and troubleshooting.

Full Script
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
    "GP": {"url": "https://grameenphone.com", "timeout": 5},
    "Banglalink": {"url": "https://banglalink.net", "timeout": 5},
    "Teletalk": {"url": "https://teletalk.com.bd", "timeout": 5},
    "Robi": {"url": "https://robi.com.bd", "timeout": 5},
}

ALERT_INTERVAL = 120
SLOW_THRESHOLD = 3
RETRY_COUNT = 2
RETRY_DELAY = 1

WEBHOOK_PROXIES = {
    "http": "http://x.x.x:8080",
    "https": "http://x..x.x:8080"
}

WEBHOOK_URL = "YOUR_WEBHOOK_URL"

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

LOG_FILE = os.path.join(LOG_DIR, "mno_monitoring.log")

logger = logging.getLogger("mno_monitoring")
logger.setLevel(logging.INFO)

handler = RotatingFileHandler(
    LOG_FILE,
    maxBytes=5 * 1024 * 1024,   # 5MB
    backupCount=5
)

formatter = logging.Formatter(
    "%(asctime)s | %(levelname)s | %(message)s",
    "%Y-%m-%d %H:%M:%S"
)

handler.setFormatter(formatter)
logger.addHandler(handler)

# Optional: also print to console
console = logging.StreamHandler()
console.setFormatter(formatter)
logger.addHandler(console)


def log(msg):
    logger.info(msg)


# ========================
# UTIL
# ========================

def resolve_dns(url):
    try:
        host = url.split("//")[1].split("/")[0]
        socket.gethostbyname(host)
        return True
    except Exception:
        return False


def check_http(url, timeout):
    for attempt in range(RETRY_COUNT + 1):
        try:
            start = time.time()
            r = requests.get(url, timeout=timeout)
            response_time = time.time() - start

            if 200 <= r.status_code < 300:
                return "UP", response_time
            elif r.status_code in [301, 302, 401, 403]:
                return "UP", response_time
            else:
                return "DOWN", response_time

        except Exception:
            if attempt < RETRY_COUNT:
                time.sleep(RETRY_DELAY)
            else:
                return "DOWN", 0


# ========================
# TEAMS FORMAT
# ========================

def format_status(status):
    if status in ["DOWN", "DNS_FAIL"]:
        return '<font color="red"><b>DOWN</b></font>'
    elif status == "SLOW":
        return '<font color="orange"><b>SLOW</b></font>'
    else:
        return '<font color="green"><b>UP</b></font>'


def send_teams_card(results):
    try:
        table_lines = []

        table_lines.append("| **Service** | **Status** | **Response** | **URL** |")
        table_lines.append("|:--|:--|:--|:--|")

        for r in results:
            response_str = "{:.2f}s".format(r["response"])
            status_display = format_status(r["status"])

            table_lines.append(
                f"| {r['name']} | {status_display} | {response_str} | {r['url']} |"
            )

        table = "\n".join(table_lines)

        # Identify DOWN services
        down_services = [r['name'] for r in results if r['status'] in ['DOWN', 'DNS_FAIL']]

        # Action block (only if needed)
        action_block = ""
        if down_services:
            action_block = (
                f"\n\n<font color='red'><b>Action Required (SOC):</b></font>  \n"
                f"- Verify network connectivity.  \n"
                f"- If connectivity is confirmed and the issue persists, please coordinate with the ({', '.join(down_services)})"
            )

        payload = {
            "@type": "MessageCard",
            "@context": "http://schema.org/extensions",
            "summary": "Endpoint Monitoring",
            "themeColor": "FF0000" if down_services else "00FF00",
            "title": "Endpoint Monitoring Summary",
            "text": (
                f"**Server:** {HOSTNAME}  \n"
                f"**Time:** {datetime.now():%F %T}  \n\n"
                f"{table}"
                f"{action_block}"
            )
        }

        r = requests.post(WEBHOOK_URL, json=payload, timeout=5, proxies=WEBHOOK_PROXIES)

        # Log response status
        log(f"Webhook response code: {r.status_code}")

        # Log failure details
        if r.status_code not in (200, 202):
            log(f"Webhook failed: {r.text}")

        return r.status_code in (200, 202)

    except Exception as e:
        log(f"WEBHOOK ERROR: {e}")
        return False,


# ========================
# MAIN
# ========================

log("URL Monitor started")

now = int(time.time())
results = []
send_required = False

for name, cfg in TARGETS.items():
    url = cfg["url"]
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

    status = "UP"
    response_time = 0

    if not resolve_dns(url):
        status = "DNS_FAIL"
    else:
        status, response_time = check_http(url, timeout)

        if status == "UP" and response_time > SLOW_THRESHOLD:
            status = "SLOW"

    time_since_last = now - last_alert if last_alert else 0

    log(f"{name} | status={status} | state={state} | last_alert={time_since_last}s")

    if status in ["DOWN", "SLOW", "DNS_FAIL"]:

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
        "url": url,
        "status": status,
        "response": response_time
    })


priority = {"DOWN": 0, "DNS_FAIL": 0, "SLOW": 1, "UP": 2}
results.sort(key=lambda x: priority.get(x["status"], 3))


if send_required:
    log("FINAL DECISION -> Sending Teams alert")
    if send_teams_card(results):
        log("TEAMS ALERT SENT")
    else:
        log("TEAMS ALERT FAILED")
else:
    log("FINAL DECISION -> No alert needed")

log("URL Monitor finished")
```
