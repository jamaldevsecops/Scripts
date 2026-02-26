# 📝 Log Compression Script - Use Cases

## 📌 Description / Purpose
This script compresses `.log` files older than a specified number of days and moves them to a destination directory. Useful for automating log rotation and maintaining storage.

## 📂 Generate Dummy Files
```
#!/bin/bash
set -euo pipefail

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

      # Create file
      touch "$FILE"

      # Set file mtime+atime to match the date (00:00:00)
      # Format: [[CC]YY]MMDDhhmm[.ss]
      touch -t "${date//-/}0000.00" "$FILE"

      chmod 640 "$FILE"
      chown ops:ops "$FILE" 2>/dev/null || true  # Only works if user:group exists
      echo "Created: $FILE (timestamp set to ${date} 00:00:00)"
    done
  done
done
```

## 🖥️ Script

```bash
#!/bin/bash
set -euo pipefail

# =====================================================
# Archive Logs By FILE DATE (mtime)
# Groups logs by actual file modification date.
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

# Compute cutoff date (ISO format allows string comparison)
CUTOFF_DATE=$(date -d "-$KEEP_LAST_DAYS day" +%Y-%m-%d)
echo "⏳ Cutoff date: $CUTOFF_DATE"

# ===================== BUILD DATE GROUPS (Single Pass) =====================
declare -A DATE_FILES

# %TY-%Tm-%Td = file mtime date
while IFS=$'\t' read -r FILE_DATE FILE_PATH; do
    if [[ "$FILE_DATE" < "$CUTOFF_DATE" ]]; then
        if [[ -z "${DATE_FILES[$FILE_DATE]+x}" ]]; then
            DATE_FILES["$FILE_DATE"]="$(mktemp)"
        fi
        printf '%s\n' "$FILE_PATH" >> "${DATE_FILES[$FILE_DATE]}"
    fi
done < <(find "$SOURCE_DIR" -type f -name "*.log" -printf '%TY-%Tm-%Td\t%p\n')

if [[ ${#DATE_FILES[@]} -eq 0 ]]; then
    echo "⚠️  No log files older than cutoff found."
    exit 0
fi

# ===================== PROCESS EACH DATE =====================
for DATE in "${!DATE_FILES[@]}"; do
    TMP_LIST="${DATE_FILES[$DATE]}"

    if [[ ! -s "$TMP_LIST" ]]; then
        rm -f "$TMP_LIST"
        continue
    fi

    echo "🔍 Processing logs for file-date: $DATE"

    ARCHIVE_NAME="${COMPONENT}-${DATE}.tar.gz"
    echo "🌀 Creating combined archive: ${ARCHIVE_NAME}"

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
done

echo "🎯 Done. All logs older than ${KEEP_LAST_DAYS} day(s) archived (by actual file date)."
```

---
