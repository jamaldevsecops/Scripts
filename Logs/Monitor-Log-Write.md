# Log Traffic Monitor Script

## Objective

This script monitors **application access logs** (such as Apache, Nginx,
or custom app logs) and detects situations where:

-   The service process may still be running
-   **But no traffic is reaching the service** (no new log entries)

This helps detect **real outages** that uptime or port checks cannot
detect (e.g., load balancer issues, firewall blocks, upstream failures).

Alerts are sent to **Microsoft Teams via Webhook** with: - Severity
(WARNING / CRITICAL) - Repeat interval (Alertmanager-like behavior) -
Per-log maintenance windows - Optional proxy support (auto-detected)

------------------------------------------------------------------------

## Key Features

-   Per-log service name
-   Per-log maintenance window
-   Severity escalation
-   Repeat alerts (group interval)
-   Recovery notification
-   Cron-safe execution
-   Works with or without proxy

------------------------------------------------------------------------

## Configuration Section

### LOGS (Per-log configuration)

``` python
LOGS = {
    "/var/log/apache2/access.log": {
        "service": "Apache",
        "maintenance_from": "10:20:00",
        "maintenance_to":   "10:20:00",
    },
    "/var/log/mylog": {
        "service": "MyLog",
        "maintenance_from": "10:23:00",
        "maintenance_to":   "10:25:00",
    },
}
```

#### Explanation

  Field              Meaning
  ------------------ -------------------------------
  log path           Absolute path to the log file
  service            Name shown in Teams alert
  maintenance_from   Start time (HH:MM:SS, 24h)
  maintenance_to     End time (HH:MM:SS, 24h)

During the maintenance window: - Alerts are **suppressed** - No alert
state is changed - Alerts resume automatically afterward

------------------------------------------------------------------------

### LOG_MONITORING_THRESHOLD

``` python
LOG_MONITORING_THRESHOLD = 30  # seconds
```

-   Time with **no new log entries** before alert triggers
-   Example: 30 seconds = alert if no traffic for 30 seconds

------------------------------------------------------------------------

### GROUP_INTERVAL

``` python
GROUP_INTERVAL = 60  # seconds
```

-   Repeat alert interval while the issue persists
-   Prevents alert flooding
-   Similar to Alertmanager `group_interval`

------------------------------------------------------------------------

### CRITICAL_MULTIPLIER

``` python
CRITICAL_MULTIPLIER = 2
```

Severity rules: - WARNING → idle \>= threshold - CRITICAL → idle \>=
threshold × multiplier

Example: - Threshold = 30s - CRITICAL after 60s

------------------------------------------------------------------------

## Proxy Configuration (Important)

The script **does not hardcode proxy settings**.

It automatically detects proxy from environment variables:

-   `HTTP_PROXY`
-   `HTTPS_PROXY`
-   `NO_PROXY`

### Recommended (System-wide)

Edit `/etc/environment`:

``` bash
HTTP_PROXY=http://192.168.20.126:8080
HTTPS_PROXY=http://192.168.20.126:8080
NO_PROXY=localhost,127.0.0.1
```

Log out / reboot after setting.

------------------------------------------------------------------------

### Cron-specific Proxy (Alternative)

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

## Cron Setup

``` bash
* * * * * python3 /root/log_traffic_monitor.py
```

Runs every minute.

------------------------------------------------------------------------

## Teams Alert Example

    🔴 Apache Log Traffic Stuck (CRITICAL)

    Server: server01
    Log File: /var/log/apache2/access.log
    Idle Time: 00:01:15

    Meaning:
    No user traffic reached Apache.
    This alert repeats every 1 minute while the issue persists.

------------------------------------------------------------------------

## Log File

Local log for debugging:

    /tmp/log_traffic_monitor.log

------------------------------------------------------------------------

## Summary

This script provides **enterprise-grade log silence detection** and
complements Prometheus/Uptime checks by detecting **traffic loss**, not
just service availability.
