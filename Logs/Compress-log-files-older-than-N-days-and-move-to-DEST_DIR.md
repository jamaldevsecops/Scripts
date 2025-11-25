# 📝 Log Compression Script - Use Cases

## 📌 Description / Purpose
This script compresses `.log` files older than a specified number of days and moves them to a destination directory. Useful for automating log rotation and maintaining storage.

## 📂 Generate Dummy Files
```
#!/bin/bash

# Instances
INSTANCES=(1 2 3)

# Dates
DATES=("2025-11-22" "2025-11-23" "2025-11-24" "2025-11-25")

# Log index (0,1,2)
LOG_INDEX=(0 1 2)


# Create files
for inst in "${INSTANCES[@]}"; do
  for date in "${DATES[@]}"; do
    for idx in "${LOG_INDEX[@]}"; do
      FILE="./ops-INST_${inst}-${date}-00-${idx}.log"
      touch "$FILE"
      chmod 640 "$FILE"
      chown ops:ops "$FILE" 2>/dev/null   # Only works if user:group exists
      echo "Created: $FILE"
    done
  done
done
```

## 🖥️ Script

```bash
#!/bin/bash
set -euo pipefail

# =====================================================
# Archive Logs By Date Script (Optimized Version)
# Keeps original logic & icons, only improves efficiency.
# =====================================================

# ===================== CONFIGURABLE VARIABLES =====================
SOURCE_DIR="/home/ops/log/archive"
DEST_DIR="/home/ops/log/archive"
COMPONENT="ops"
KEEP_LAST_DAYS=${2:-2}      # Default keep last 2 days
KEEP_SOURCE=false           # Set true to keep original logs
# ==================================================================

# Ensure destination exists
if [[ ! -d "$DEST_DIR" ]]; then
    echo "📁 Destination directory not found, creating: $DEST_DIR"
    mkdir -p "$DEST_DIR"
else
    echo "📂 Destination directory exists: $DEST_DIR"
fi

echo "📁 Source: $SOURCE_DIR"
echo "📁 Destination: $DEST_DIR"
echo "🧭 Keeping last $KEEP_LAST_DAYS day(s), archiving older ones..."
echo "------------------------------------------------------------"

# ===================== OPTIMIZED DATE EXTRACTION =====================
# Faster, safer: avoids ls, handles 1000s of files properly
mapfile -t ALL_DATES < <(
    find "$SOURCE_DIR" -type f -name "*.log" \
    | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | sort -u
)

if [[ ${#ALL_DATES[@]} -eq 0 ]]; then
    echo "⚠️  No log files found in $SOURCE_DIR"
    exit 0
fi

# Compute cutoff date
CUTOFF_DATE=$(date -d "-$KEEP_LAST_DAYS day" +%Y-%m-%d)
echo "⏳ Cutoff date: $CUTOFF_DATE"

# ===================== PROCESS EACH DATE =====================
for DATE in "${ALL_DATES[@]}"; do

    if [[ "$DATE" < "$CUTOFF_DATE" ]]; then
        echo "🔍 Processing logs for date: $DATE"

        TMP_LIST=$(mktemp)

        # Faster than find + grep repeatedly
        find "$SOURCE_DIR" -type f -name "*${DATE}*.log" > "$TMP_LIST"

        if [[ ! -s "$TMP_LIST" ]]; then
            echo "⚠️  No files found for ${DATE}. Skipping..."
            rm -f "$TMP_LIST"
            continue
        fi

        ARCHIVE_NAME="${COMPONENT}-${DATE}.tar.gz"
        echo "🌀 Creating combined archive: ${ARCHIVE_NAME}"

        # Improved: remove full path, keep filenames only
        tar -czf "${DEST_DIR}/${ARCHIVE_NAME}" \
            -T "$TMP_LIST" \
            --transform='s|^.*/||'

        echo "✅ Successfully created: ${DEST_DIR}/${ARCHIVE_NAME}"

        if [[ "$KEEP_SOURCE" == false ]]; then
            echo "🗑️  Removing original files for ${DATE}..."
            xargs -a "$TMP_LIST" rm -f
        else
            echo "♻️  KEEP_SOURCE=true — originals retained."
        fi

        rm -f "$TMP_LIST"
        echo "------------------------------------------------------------"

    else
        echo "⏭️  Skipping ${DATE} (within last ${KEEP_LAST_DAYS} days)"
    fi
done

echo "🎯 Done. All logs older than ${KEEP_LAST_DAYS} day(s) archived."
```

---
