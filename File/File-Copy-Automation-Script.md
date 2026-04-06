# 📦 File Copy Automation Script (Production Summary)

## 🚀 Overview

This script reads a CSV file, extracts all `/documents/...` file paths, and copies those files from a source directory to a destination directory using `rsync`.

---

## ⚙️ What It Does

- Copies files from **source → destination** while preserving directory structure  
- Supports **any file type**  
- Skips files that already exist  
- Tracks:
  - ✔️ Newly copied files  
  - ✔️ Already existing files  
  - ✔️ Missing source files  
  - ✔️ Rsync failures  

---

## 🔁 Reliability

- Retries failed copies automatically  
- Uses low CPU and disk priority (`nice`, `ionice`)  
- Safe for concurrent runs using file locking  

---

## 📊 Logging & Monitoring

- Creates structured logs per job and globally  
- Maintains a global copy counter  
- Triggers a remount after large copy volume  
- Sends status updates to Microsoft Teams (table format via webhook and proxy)  

---

## ✅ Features Summary

### 📁 File Handling

- ✔️ Supports **any file type** (no `.jpeg` dependency)  
- ✔️ Extracts `/documents...` paths from CSV  
- ✔️ Copies files using `rsync`  
- ✔️ Preserves directory structure  
- ✔️ Creates destination directories automatically  
- ✔️ Skips existing files (`--ignore-existing`)  

---

### 📊 Logging

- ✔️ Dynamic `logs/` directory beside script  
- ✔️ Per-job logs:
  - `run.log`
  - `missing_urls.txt`
  - `rsync_failed_urls.txt`
- ✔️ Global logs:
  - `running.log`
  - `completed.log`
  - `copy_counter.txt`

---

### 🔍 Accurate Tracking

Tracks:

- ✔️ Newly copied files (`COPIED_COUNT`)  
- ✔️ Already existing files (`EXISTING_COUNT`)  
- ✔️ Missing files (`MISSING_COUNT`)  
- ✔️ Rsync failures (`RSYNC_FAIL_COUNT`)  

---

### 🔁 Reliability

- ✔️ Retry mechanism for rsync failures  
- ✔️ Configurable retry count and delay  

---

### 🔐 Concurrency Safety

- ✔️ Uses `flock` for locking  
- ✔️ Prevents race conditions  
- ✔️ Safe for parallel execution  

---

### 🔢 Global Counter & Remount

- ✔️ Counts only newly copied files  
- ✔️ Triggers remount after threshold (1,000,000 files)  
- ✔️ Resets counter after remount  
- ✔️ Sends Teams alert on trigger  

---

### 🌐 Teams Notification

- ✔️ Webhook integration  
- ✔️ Proxy support (HTTP/HTTPS)  
- ✔️ Notifications:
  - Job start  
  - Remount trigger  
  - Job completion  
- ✔️ Output formatted as structured table  

---

### ⚙️ Performance Optimization

- ✔️ `ionice` → Low disk I/O priority  
- ✔️ `nice` → Low CPU priority  

---

### 🛡️ Safety & Validation

- ✔️ Argument validation  
- ✔️ CSV file existence check  
- ✔️ Safe execution (`set -euo pipefail`)  


---

## 📜 Script

```bash
#!/bin/bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <csv_file>"
    exit 1
fi

CSV="$1"

if [[ ! -f "$CSV" ]]; then
    echo "ERROR: CSV file not found: $CSV"
    exit 2
fi

SRC_BASE="/document2"
DEST_BASE="/tmp/devops/dest"

########################################
# LOG DIRECTORY
########################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_BASE="$SCRIPT_DIR/logs"

JOB=$(basename "$CSV" .csv)

CSV_LOG_DIR="$LOG_BASE/$JOB"
mkdir -p "$CSV_LOG_DIR"

CSV_LOG="$CSV_LOG_DIR/run.log"
MISS="$CSV_LOG_DIR/missing_urls.txt"
FAILED_RSYNC="$CSV_LOG_DIR/rsync_failed_urls.txt"

GLOBAL_LOG="$LOG_BASE/running.log"
COMPLETED_LOG="$LOG_BASE/completed.log"

########################################
# GLOBAL COUNTER + REMOUNT CONFIG
########################################

COUNTER_FILE="$LOG_BASE/copy_counter.txt"
REMOUNT_SCRIPT="/home/scripts/customerdoc2/script/remount_document2.sh"
LOCK_FILE="/tmp/copy_counter.lock"

########################################
# TEAMS WEBHOOK + PROXY CONFIG
########################################

TEAMS_WEBHOOK_URL="https://YOUR-TEAMS-WEBHOOK-URL"
HTTP_PROXY="http://192.168.20.200:9999"
HTTPS_PROXY="http://192.168.20.200:9999"

export HTTP_PROXY HTTPS_PROXY
export http_proxy="$HTTP_PROXY"
export https_proxy="$HTTPS_PROXY"

########################################
# HOST INFO
########################################

HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname)"
RUN_USER="$(whoami 2>/dev/null || echo unknown)"

########################################
# RETRY CONFIG
########################################

MAX_RSYNC_RETRIES=3
RETRY_SLEEP_SECONDS=5

########################################
# COUNTERS
########################################

COPIED_COUNT=0
EXISTING_COUNT=0
MISSING_COUNT=0
RSYNC_FAIL_COUNT=0

########################################
# FUNCTIONS
########################################

escape_json_string() {
    local s="${1:-}"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/}"
    printf '%s' "$s"
}

build_teams_table() {
    local status="$1"
    local total="$2"
    local copied="$3"
    local existing="$4"
    local missing="$5"
    local failed="$6"
    local event_time="$7"

    cat <<EOF
<table border="1" style="border-collapse:collapse; width:100%;">
  <tr>
    <th align="left">Field</th>
    <th align="left">Value</th>
  </tr>
  <tr>
    <td>Status</td>
    <td>$status</td>
  </tr>
  <tr>
    <td>Job</td>
    <td>$JOB</td>
  </tr>
  <tr>
    <td>Host</td>
    <td>$HOSTNAME_SHORT</td>
  </tr>
  <tr>
    <td>User</td>
    <td>$RUN_USER</td>
  </tr>
  <tr>
    <td>Total Detected Paths</td>
    <td>$total</td>
  </tr>
  <tr>
    <td>Newly Copied</td>
    <td>$copied</td>
  </tr>
  <tr>
    <td>Already Existing / Skipped</td>
    <td>$existing</td>
  </tr>
  <tr>
    <td>Missing</td>
    <td>$missing</td>
  </tr>
  <tr>
    <td>Rsync Failed</td>
    <td>$failed</td>
  </tr>
  <tr>
    <td>Time</td>
    <td>$event_time</td>
  </tr>
</table>
EOF
}

build_remount_table() {
    local global_counter="$1"
    local event_time="$2"

    cat <<EOF
<table border="1" style="border-collapse:collapse; width:100%;">
  <tr>
    <th align="left">Field</th>
    <th align="left">Value</th>
  </tr>
  <tr>
    <td>Status</td>
    <td>Remount Triggered</td>
  </tr>
  <tr>
    <td>Job</td>
    <td>$JOB</td>
  </tr>
  <tr>
    <td>Host</td>
    <td>$HOSTNAME_SHORT</td>
  </tr>
  <tr>
    <td>User</td>
    <td>$RUN_USER</td>
  </tr>
  <tr>
    <td>Global Counter</td>
    <td>$global_counter</td>
  </tr>
  <tr>
    <td>Remount Script</td>
    <td>$REMOUNT_SCRIPT</td>
  </tr>
  <tr>
    <td>Time</td>
    <td>$event_time</td>
  </tr>
</table>
EOF
}

send_teams_notification() {
    local title="$1"
    local table_html="$2"
    local color="${3:-0076D7}"

    [ -z "$TEAMS_WEBHOOK_URL" ] && return 0

    local title_json
    local table_json
    title_json="$(escape_json_string "$title")"
    table_json="$(escape_json_string "$table_html")"

    local payload
    payload=$(cat <<EOF
{
  "@type": "MessageCard",
  "@context": "http://schema.org/extensions",
  "themeColor": "$color",
  "summary": "$title_json",
  "title": "$title_json",
  "text": "$table_json"
}
EOF
)

    curl -sS --fail --proxy "$HTTPS_PROXY" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$TEAMS_WEBHOOK_URL" >> "$CSV_LOG" 2>&1 || true
}

update_global_counter_and_remount_if_needed() {
    (
        flock -x 200

        COUNT_GLOBAL=$(cat "$COUNTER_FILE")
        COUNT_GLOBAL=$((COUNT_GLOBAL + 1))
        echo "$COUNT_GLOBAL" > "$COUNTER_FILE"

        if (( COUNT_GLOBAL >= 1000000 )); then
            echo "REMOUNT TRIGGERED at $COUNT_GLOBAL $(date)" | tee -a "$CSV_LOG" "$GLOBAL_LOG"

            REMOUNT_TABLE="$(build_remount_table "$COUNT_GLOBAL" "$(date)")"
            send_teams_notification \
                "Remount Triggered" \
                "$REMOUNT_TABLE" \
                "FFA500"

            bash "$REMOUNT_SCRIPT" >> "$CSV_LOG" 2>&1 || true

            echo 0 > "$COUNTER_FILE"
        fi
    ) 200>"$LOCK_FILE"
}

rsync_with_retry() {
    local src="$1"
    local dest="$2"

    local attempt=1

    while (( attempt <= MAX_RSYNC_RETRIES )); do
        echo "RSYNC_ATTEMPT [$JOB] attempt=$attempt/$MAX_RSYNC_RETRIES src=$src dest=$dest $(date)" >> "$CSV_LOG"

        if ionice -c3 nice -n 19 rsync -a \
            --ignore-existing \
            --bwlimit=4000 \
            "$src" "$dest" >> "$CSV_LOG" 2>&1
        then
            return 0
        fi

        if (( attempt < MAX_RSYNC_RETRIES )); then
            echo "RSYNC_RETRY [$JOB] attempt=$attempt failed for $src ; sleeping ${RETRY_SLEEP_SECONDS}s before retry $(date)" | tee -a "$CSV_LOG" "$GLOBAL_LOG"
            sleep "$RETRY_SLEEP_SECONDS"
        fi

        attempt=$((attempt + 1))
    done

    return 1
}

########################################
# INIT
########################################

[ -f "$COUNTER_FILE" ] || echo 0 > "$COUNTER_FILE"
touch "$CSV_LOG" "$MISS" "$FAILED_RSYNC" "$GLOBAL_LOG"

########################################
# COUNT TOTAL URLS
########################################

TOTAL=$(grep -oE '/documents[^",[:space:]]+' "$CSV" | wc -l)

COUNT=0

########################################
# START LOG
########################################

echo "START CSV=$JOB TOTAL=$TOTAL $(date)" | tee -a "$CSV_LOG" "$GLOBAL_LOG"

START_TABLE="$(build_teams_table "Started" "$TOTAL" "0" "0" "0" "0" "$(date)")"
send_teams_notification \
    "Copy Job Started" \
    "$START_TABLE" \
    "0076D7"

########################################
# PROCESS URLS
########################################

while read -r REL_PATH
do
    [ -z "$REL_PATH" ] && continue

    COUNT=$((COUNT + 1))

    SRC="$SRC_BASE$REL_PATH"
    DEST="$DEST_BASE$REL_PATH"
    DEST_DIR=$(dirname "$DEST")

    MSG="COPYING [$JOB] [$COUNT/$TOTAL] $SRC --> $DEST"

    if (( COUNT % 1000 == 0 )); then
        echo "$MSG" | tee -a "$CSV_LOG" "$GLOBAL_LOG"
    fi

    if [ -f "$SRC" ]; then
        mkdir -p "$DEST_DIR"

        DEST_ALREADY_EXISTS=0
        if [ -e "$DEST" ]; then
            DEST_ALREADY_EXISTS=1
        fi

        if rsync_with_retry "$SRC" "$DEST"; then
            if (( DEST_ALREADY_EXISTS == 1 )); then
                EXISTING_COUNT=$((EXISTING_COUNT + 1))
                echo "SKIPPED_EXISTING [$JOB] $REL_PATH" >> "$CSV_LOG"
            else
                COPIED_COUNT=$((COPIED_COUNT + 1))
                update_global_counter_and_remount_if_needed
            fi
        else
            RSYNC_FAIL_COUNT=$((RSYNC_FAIL_COUNT + 1))
            echo "$REL_PATH" >> "$FAILED_RSYNC"
            echo "RSYNC_FAILED [$JOB] $REL_PATH" | tee -a "$CSV_LOG" "$GLOBAL_LOG"
        fi
    else
        MISSING_COUNT=$((MISSING_COUNT + 1))
        echo "$REL_PATH" >> "$MISS"
        echo "MISSING [$JOB] $REL_PATH" | tee -a "$CSV_LOG" "$GLOBAL_LOG"
    fi

done < <(grep -oE '/documents[^",[:space:]]+' "$CSV")

########################################
# FINISH LOG
########################################

echo "FINISHED CSV $JOB $(date)" | tee -a "$CSV_LOG" "$GLOBAL_LOG"
echo "SUMMARY [$JOB] TOTAL=$TOTAL COPIED=$COPIED_COUNT EXISTING=$EXISTING_COUNT MISSING=$MISSING_COUNT RSYNC_FAILED=$RSYNC_FAIL_COUNT $(date)" | tee -a "$CSV_LOG" "$GLOBAL_LOG"

########################################
# MARK AS COMPLETED
########################################

grep -q "^$JOB - done$" "$COMPLETED_LOG" 2>/dev/null || \
echo "$JOB - done" >> "$COMPLETED_LOG"

########################################
# FINAL TEAMS NOTIFICATION
########################################

FINISH_TABLE="$(build_teams_table \
    "Finished" \
    "$TOTAL" \
    "$COPIED_COUNT" \
    "$EXISTING_COUNT" \
    "$MISSING_COUNT" \
    "$RSYNC_FAIL_COUNT" \
    "$(date)"
)"

send_teams_notification \
    "Copy Job Finished" \
    "$FINISH_TABLE" \
    "28A745"
```

---

## 🎯 Final Outcome

A fully **enterprise-ready automation script** with:
- Accurate reporting
- Failure handling
- Logging & monitoring
- Teams integration
- Proxy compatibility

---

## 🔥 Future Enhancements
- Parallel execution
- Failure reprocessing queue
- Log rotation
- Audit-grade MOP documentation
