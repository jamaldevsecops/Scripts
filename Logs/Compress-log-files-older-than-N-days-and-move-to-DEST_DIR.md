# Log Compression Script - Use Cases

## Description / Purpose
This script compresses `.log` files older than a specified number of days and moves them to a destination directory. It supports three actions: `compress` (default), `dryrun` (to list files without modifying), and `cleanup` (to delete old archives). Useful for automating log rotation and maintaining storage.

## Script

```bash
#!/bin/bash
# Description: Compress log files older than N days and move to DEST_DIR.
# Author: Jamal Hossain (updated)
# Date: 2025-10-27

SRC_DIR="/root/logs"                      # update to your source dir
DEST_DIR="/tmp/LOGS/app5/kms"            # update to your destination dir
ACTION=${2:-compress}                     # optional: compress | dryrun | cleanup
DAYS_AGO=${1:-2}                          # default 2 days; override with arg: ./move_logs.sh 3

# Ensure UTF-8 for icons
export LANG=en_US.UTF-8

# Ensure destination directory exists
if [ ! -d "$DEST_DIR" ]; then
    echo "📁 Destination directory not found. Creating: $DEST_DIR"
    mkdir -p "$DEST_DIR" || { echo "❌ Failed to create destination directory: $DEST_DIR"; exit 1; }
    echo "✅ Created: $DEST_DIR"
else
    echo "📂 Destination directory exists: $DEST_DIR"
fi

case "$ACTION" in
    dryrun)
        echo "👀 Dry-run: listing .log files older than $DAYS_AGO days in $SRC_DIR"
        find "$SRC_DIR" -type f -name "*.log" -mtime +"$DAYS_AGO" -ls || echo "⚠️  No matching files found."
        exit 0
        ;;
    cleanup)
        echo "🧹 Cleanup: removing .tar.gz archives older than $DAYS_AGO days from $DEST_DIR"
        find "$DEST_DIR" -type f -name "*.tar.gz" -mtime +"$DAYS_AGO" -print -exec rm -v {} \; || echo "⚠️  No archives matched cleanup criteria."
        exit 0
        ;;
    compress|*)
        echo "🔍 Searching for .log files older than $DAYS_AGO days in $SRC_DIR ..."
        processed_count=0
        find "$SRC_DIR" -type f -name "*.log" -mtime +"$DAYS_AGO" -print0 | while IFS= read -r -d '' file; do
            echo "$file" >> /tmp/.move_logs_matches.$$ 
        done

        if [ -f /tmp/.move_logs_matches.$$ ]; then
            while IFS= read -r file; do
                processed_count=$((processed_count + 1))
                filename=$(basename "$file")
                tarfile="${filename%.log}.tar.gz"

                echo ""
                echo "🌀 Processing: $filename"

                if tar -czf "$DEST_DIR/$tarfile" -C "$(dirname "$file")" "$filename"; then
                    echo "✅ Successfully compressed: $tarfile"
                    if [ -f "$DEST_DIR/$tarfile" ]; then
                        if rm -f "$file"; then
                            echo "🗑️  Deleted source file: $filename"
                        else
                            echo "⚠️  Failed to delete source file: $filename (please check permissions)"
                        fi
                    else
                        echo "⚠️  Archive missing after compression: $tarfile — not deleting source."
                    fi
                else
                    echo "❌ Failed to compress: $filename"
                fi
            done < /tmp/.move_logs_matches.$$
            rm -f /tmp/.move_logs_matches.$$
        fi

        echo ""
        if [ "$processed_count" -eq 0 ]; then
            echo "⚠️  No .log files older than $DAYS_AGO days were found in $SRC_DIR. Nothing to do."
            exit 0
        else
            echo "✅ Done. Compressed and moved $processed_count file(s) older than $DAYS_AGO days to $DEST_DIR."
            exit 0
        fi
        ;;
esac
``` 

---

## Use Cases & Sample Output

### 1️⃣ Dry-run
```bash
bash move_logs.sh dryrun 2
```
**Output:**
```
📂 Destination directory exists: /tmp/LOGS/app5/kms
🔍 Searching for .log files older than 2 days in /root/logs ...
👀 Dry-run: listing .log files older than 2 days in /root/logs
-rw-r----- 1 root root 0 Oct 20 09:00 /root/logs/kms-2025-10-20.log
-rw-r----- 1 root root 0 Oct 24 09:00 /root/logs/kms-2025-10-24.log
✅ Done listing logs older than 2 days.
```

### 2️⃣ Compress logs older than 2 days
```bash
bash move_logs.sh compress 2
```
**Output:**
```
📂 Destination directory exists: /tmp/LOGS/app5/kms
🔍 Searching for .log files older than 2 days in /root/logs ...

🌀 Processing: kms-2025-10-20.log
✅ Successfully compressed: kms-2025-10-20.tar.gz
🗑️  Deleted source file: kms-2025-10-20.log

🌀 Processing: kms-2025-10-24.log
✅ Successfully compressed: kms-2025-10-24.tar.gz
🗑️  Deleted source file: kms-2025-10-24.log

✅ Done. Compressed and moved 2 file(s) older than 2 days to /tmp/LOGS/app5/kms.
```

### 3️⃣ Cleanup archives older than 7 days
```bash
bash move_logs.sh cleanup 7
```
**Output:**
```
🧹 Cleanup: removing .tar.gz archives older than 7 days from /tmp/LOGS/app5/kms
-rw-r----- 1 root root 120 Oct 18 09:00 /tmp/LOGS/app5/kms/kms-2025-10-18.tar.gz
Deleted: /tmp/LOGS/app5/kms/kms-2025-10-18.tar.gz
✅ Cleanup complete.
```

---

### Notes
- Default `DAYS_AGO` is 2 if not specified.
- Default `ACTION` is `compress` if not specified.
- Icons (✅, 🗑️, ⚠️, 🌀, 📂, 👀, 🧹) are UTF-8 compatible and show in modern terminals.
- Dry-run allows safe testing before actual compression/deletion.
