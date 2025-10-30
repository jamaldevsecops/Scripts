# 🗂️ Log Archiving Automation Overview

This document provides a complete overview of the **log archive automation setup**, including how to generate dummy logs, use the archiving script, and understand its workflow.

---

## 📘 Overview

This setup helps you:
- Generate dummy log files for testing
- Automatically archive log files based on date
- Keep logs for the last *N* days (customizable)
- Automatically delete source logs after successful archiving

---

## 🧩 Components

### 1️⃣ Dummy Log Generator (`generate_dummy_logs.sh`)

#### **Purpose**
Creates fake `.tar.gz` log files for testing your archive automation.

#### **Key Variables**
| Variable | Description | Example |
|-----------|--------------|----------|
| `COMPONENT` | Component name | `apigw-summary` |
| `INSTANCES` | Number of instances | `3` |
| `TOTAL_DAYS` | Number of days (including today) | `10` |
| `APP_NAME` | Application tag | `nagad-app11` |

#### **Example Script Execution**
```bash
bash generate_dummy_logs.sh
```

#### **Sample Output**
```
📦 Generating dummy log archives for component: apigw-summary
🧩 Instances: 3 | 🗓️  Total Days: 10
📁 Source Directory: /tmp/home/apigw-summary/logs/archive
-----------------------------------------------------
🗓️  Created logs for date: 2025-10-30
🗓️  Created logs for date: 2025-10-29
...
✅ Dummy logs created successfully!
🧾 Total files created: 90
```

---

### 2️⃣ Archive Script (`archive_logs_by_date.sh`)

#### **Purpose**
Archives log files for all days older than the *KEEP_LAST_DAYS* threshold and moves them to the destination directory.

#### **Key Variables (Default Configurable at Top)**

| Variable | Description | Default |
|-----------|--------------|----------|
| `COMPONENT` | Component name (can be passed as argument) | `apigw` |
| `KEEP_LAST_DAYS` | Number of recent days to keep | `2` |
| `APP_NAME` | App name tag used in archive filename | `nagad-app11` |
| `SRC_DIR` | Source log directory | `/tmp/home/$COMPONENT/logs/archive` |
| `DEST_DIR` | Destination directory | `/tmp/LOGS/app11/$COMPONENT` |
| `KEEP_SOURCE` | Whether to keep source logs after archiving | `false` |

---

## ⚙️ Usage Examples

### 🔸 Default Usage (with defaults)
```bash
bash archive_logs_by_date.sh
```
➡️ Uses defaults: component=`apigw`, keep last 2 days.

### 🔸 Specify Component Only
```bash
bash archive_logs_by_date.sh ias
```
➡️ Archives logs for component `ias`.

### 🔸 Specify Component and Days
```bash
bash archive_logs_by_date.sh apigw-summary 3
```
➡️ Archives logs for `apigw-summary`, keeping the last **3 days**.

---

## 📦 Archive File Naming Convention

Each archive will be named as:
```
<component_name>-<app_name>-<date>.tar.gz
```
**Example:**
```
apigw-summary-nagad-app11-2025-10-27.tar.gz
```

---

## 🧾 Sample Output (Archiving Run)

```
📦 Component: apigw-summary
📂 Source: /tmp/home/apigw-summary/logs/archive
📁 Destination: /tmp/LOGS/app11/apigw-summary
📅 Processing logs older than 2 days...
----------------------------------------------
🌀 Archiving logs for date: 2025-10-27
✅ Created archive: /tmp/LOGS/app11/apigw-summary/apigw-summary-nagad-app11-2025-10-27.tar.gz
🗑️  Removed source logs for 2025-10-27
----------------------------------------------
🎯 Completed successfully.
```

---

## 🧰 Directory Structure

```
/tmp/
 ├── home/
 │    └── apigw-summary/
 │         └── logs/
 │              └── archive/
 │                   ├── apigw-summary-nagad-app11-INST_1-2025-10-27-00-0.log.tar.gz
 │                   ├── ...
 └── LOGS/
      └── app11/
           └── apigw-summary/
                ├── apigw-summary-nagad-app11-2025-10-27.tar.gz
                ├── ...
```

---

## 📋 Notes

- Automatically creates destination directory if missing.
- Deletes source files after successful archive creation.
- Ideal for log management automation via cron or systemd.

---

© 2025 Log Archiver Utility
