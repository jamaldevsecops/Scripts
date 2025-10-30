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

## 🖥️ Script for dummy log generation
```
#!/bin/bash
# =====================================================
# Dummy Log Generator for Components with Instances
# Generates fake compressed log archives for N past days
# =====================================================

# ===== CONFIGURABLE VARIABLES =====
COMPONENT=${1:-"apigw"}      # e.g., ias, apigw-summary, kms, etc. (default=apigw)
INSTANCES=${2:-3}            # number of instances (INST_1..INST_N) (default=3)
TOTAL_DAYS=10                # total days including today
APP_NAME="nagad-app11"       # optional application tag
# ==================================

# Base directory paths
SRC_DIR="/tmp/home/${COMPONENT}/logs/archive"
DEST_DIR="/tmp/LOGS/app11/${COMPONENT}"

# Create directories if they don't exist
mkdir -p "$SRC_DIR" "$DEST_DIR"

echo "📦 Generating dummy log archives for component: $COMPONENT"
echo "🧩 Instances: $INSTANCES | 🗓️  Total Days: $TOTAL_DAYS"
echo "📁 Source Directory: $SRC_DIR"
echo "-----------------------------------------------------"

# Loop through days (0 = today)
for ((i=0; i<TOTAL_DAYS; i++)); do
  DATE=$(date -d "-$i days" +%Y-%m-%d)
  for ((inst=1; inst<=INSTANCES; inst++)); do
    INST_NAME="INST_${inst}"
    for part in {0..2}; do
      FILE="${SRC_DIR}/${COMPONENT}-${APP_NAME}-${INST_NAME}-${DATE}-00-${part}.log.tar.gz"
      touch "$FILE"
      # Set file timestamp to that date
      touch -d "$DATE 00:00" "$FILE"
    done
  done
  echo "🗓️  Created logs for date: $DATE"
done

echo "✅ Dummy logs created successfully!"
echo "📂 Example files:"
ls -lh "$SRC_DIR"
echo "..."
echo "🧾 Total files created: $(ls "$SRC_DIR" | wc -l)"
```

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

## 🖥️ Archive Script
```
#!/bin/bash
set -euo pipefail

# =====================================================
# Archive Logs By Date Script
# Accepts component, optional keep last days, and optional app name
# =====================================================

# ===================== CONFIGURABLE VARIABLES =====================
COMPONENT=${1:-"apigw-summary"}             # Component name (optional, default=apigw-summary)
KEEP_LAST_DAYS=${2:-2}                      # Number of last days to skip (optional, default=2)
SERVER_HOSTNAME=${3:-"nagad-app11"}         # Application name (optional, default=nagad-app11)
KEEP_SOURCE=false                           # true to keep source files after archive
# ==================================================================

# Validate component
if [[ -z "$COMPONENT" ]]; then
    echo "Usage: $0 <component_name> [KEEP_LAST_DAYS] [SERVER_HOSTNAME]"
    exit 1
fi

# Base directories
SOURCE_DIR="/tmp/home/${COMPONENT}/logs/archive"
DEST_DIR="/tmp/LOGS/${SERVER_HOSTNAME#*-}/${COMPONENT}"

# Ensure destination exists
if [[ ! -d "$DEST_DIR" ]]; then
    echo "📁 Destination directory not found, creating: $DEST_DIR"
    mkdir -p "$DEST_DIR"
else
    echo "📂 Destination directory exists: $DEST_DIR"
fi

echo "📦 Component: $COMPONENT"
echo "📁 Source: $SOURCE_DIR"
echo "📁 Destination: $DEST_DIR"
echo "🧭 Keeping last $KEEP_LAST_DAYS day(s), archiving older ones..."
echo "📌 App Name: $SERVER_HOSTNAME"
echo "------------------------------------------------------------"

# Find all unique dates from filenames
ALL_DATES=($(ls "$SOURCE_DIR"/*.log.tar.gz 2>/dev/null \
    | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | sort -u))

if [[ ${#ALL_DATES[@]} -eq 0 ]]; then
    echo "⚠️  No log files found in $SOURCE_DIR"
    exit 0
fi

# Determine cutoff date
CUTOFF_DATE=$(date -d "-$KEEP_LAST_DAYS day" +%Y-%m-%d)
echo "⏳ Cutoff date: $CUTOFF_DATE"

# Loop through all dates older than cutoff
for DATE in "${ALL_DATES[@]}"; do
    if [[ "$DATE" < "$CUTOFF_DATE" ]]; then
        echo "🔍 Processing logs for date: $DATE"

        TMP_LIST=$(mktemp)
        find "$SOURCE_DIR" -type f -name "*${DATE}*.log.tar.gz" > "$TMP_LIST"

        if [[ ! -s "$TMP_LIST" ]]; then
            echo "⚠️  No files found for ${DATE}. Skipping..."
            rm -f "$TMP_LIST"
            continue
        fi

        ARCHIVE_NAME="${COMPONENT}-${SERVER_HOSTNAME}-${DATE}.tar.gz"
        echo "🌀 Creating combined archive: ${ARCHIVE_NAME}"

        tar -czf "${DEST_DIR}/${ARCHIVE_NAME}" -T "$TMP_LIST" --transform='s|^/||'
        if [[ $? -eq 0 ]]; then
            echo "✅ Successfully created: ${DEST_DIR}/${ARCHIVE_NAME}"
            if [[ "$KEEP_SOURCE" == false ]]; then
                echo "🗑️  Removing original files for ${DATE}..."
                xargs -a "$TMP_LIST" rm -f
            else
                echo "♻️  KEEP_SOURCE=true — originals retained."
            fi
        else
            echo "❌ Failed to create archive for ${DATE}"
        fi

        rm -f "$TMP_LIST"
        echo "------------------------------------------------------------"
    else
        echo "⏭️  Skipping ${DATE} (within last ${KEEP_LAST_DAYS} days)"
    fi
done

echo "🎯 Done. All logs older than ${KEEP_LAST_DAYS} day(s) archived."
```
If the script coppied from Windows to Linux host. (Optional)
```
sed -i 's/\r$//' archive_logs_by_date.sh
```

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

➡️ Archives 
```
00 03 * * * /scripts/archive_logs_by_date.sh >/dev/null 2>&1
```
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
