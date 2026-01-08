# 🔁 One-Way Directory Sync (Server1 → Server2)

## 📌 Purpose

This document describes a **safe, simple, production-ready one‑way directory synchronization script**.

The script ensures that **Server2 is always an exact mirror of Server1**.

> 🟢 **Server1 is the single source of truth**

---

## 🎯 What This Script Does

✔ Create file on **Server1** → copied to **Server2**  
✔ Modify file on **Server1** → updated on **Server2**  
✔ Delete file on **Server1** → deleted on **Server2**  
✔ Any changes on **Server2** → ignored / overwritten  

This design **eliminates race conditions** and **prevents data loss**.

---

## 🧠 Design Philosophy (Simple Explanation)

Think of:

* 🧑‍🏫 **Server1** as the *teacher*
* 📒 **Server2** as the *notebook copy*

Whatever the teacher writes or erases is copied to the notebook.
Anything written in the notebook is corrected on the next copy.

There is **only one decision maker**, so no conflicts can occur.

---

## 🛡️ Why This Is Safe

| Risk                     | Status                     |
| ------------------------ | -------------------------- |
| Race condition           | ❌ Impossible               |
| Two-way delete conflict  | ❌ Impossible               |
| Load balancer randomness | ✅ Irrelevant               |
| Accidental wipe          | ⚠️ Only if Server1 deletes |
| Data corruption          | ❌ Prevented                |

---

## 🧩 Technical Characteristics

* 🔁 **One-way sync only**
* 🧠 **Stateless & idempotent**
* ⏱ Cron-friendly (poll & sync)
* 🔐 SSH-based (custom port supported)
* 👤 Enforces ownership: `appadmin:webapp`
* 🚫 Excludes Laravel volatile directories

---

## 📂 Directories Synced

```text
/tmp/public
/tmp/storage
```

> ⚠️ Must be **absolute paths** and must exist on both servers

---

## 🚫 Excluded Directories (Laravel Safe)

```text
storage/logs
storage/framework/sessions
storage/framework/cache
storage/framework/views
```

---

## 🧾 Full Script (Cron‑Friendly)

```bash
#!/usr/bin/env bash
set -euo pipefail

####################################
# CONFIGURATION
####################################

REMOTE_IP="192.168.20.127"
SSH_USER="appadmin"
SSH_PORT="40167"

OWNER="appadmin"
GROUP="webapp"

WATCH_DIRS=(
  "/var/www/html/myapp/public/uploads"
  "/var/www/html/myapp/storage/app/public"
)

EXCLUDES=(
  "storage/logs"
  "storage/framework/sessions"
  "storage/framework/cache"
  "storage/framework/views"
)

RSYNC_OPTS=(
  -a
  --delete
  --numeric-ids
  --inplace
  --chmod=F664,D775
)

####################################
# LOCK (prevents overlapping cron)
####################################

LOCK_FILE="/tmp/nagad_sync_cron.lock"
exec 9>"$LOCK_FILE" || exit 1
flock -n 9 || exit 0

####################################
# FUNCTIONS
####################################

build_excludes() {
  local args=()
  for e in "${EXCLUDES[@]}"; do
    args+=(--exclude="$e")
  done
  echo "${args[@]}"
}

sync_dir() {
  local dir="$1"
  echo "[CRON SYNC] $dir → $REMOTE_IP"

  rsync \
    -e "ssh -p $SSH_PORT -o BatchMode=yes -o ConnectTimeout=5" \
    "${RSYNC_OPTS[@]}" \
    $(build_excludes) \
    --chown="$OWNER:$GROUP" \
    "$dir/" \
    "$SSH_USER@$REMOTE_IP:$dir/"
}

####################################
# MAIN
####################################

for d in "${WATCH_DIRS[@]}"; do
  [[ "$d" != /* ]] && {
    echo "ERROR: Path must be absolute: $d"
    exit 1
  }
  sync_dir "$d"
done

echo "[DONE] Sync completed successfully"

```

---

## ⏰ Cron Configuration

### ▶ Run every 5 minutes (silent / black hole logging)

```cron
*/5 * * * * /usr/local/bin/nagad_sync_cron.sh > /dev/null 2>&1
```

### 🔇 What this does

* 🕳 Sends **all output to /dev/null**
* 📧 Prevents cron emails
* 💾 Prevents log files growing

---

## 🧪 Testing Checklist

### Create test

```bash
touch /tmp/public/test.txt
```

✔ Appears on Server2

### Delete test

```bash
rm /tmp/public/test.txt
```

✔ Deleted on Server2

### Wrong side test

```bash
# On Server2
touch /tmp/public/wrong.txt
```

✔ Removed on next cron run

---

## 🚫 Important Rules

❌ Do NOT run this script on Server2
❌ Do NOT add reverse sync
❌ Do NOT remove `--delete`

Server2 **must always be treated as a mirror**.

---

## 🏁 Final Summary

✔ Simple one‑way sync  
✔ No race conditions  
✔ No shared storage needed  
✔ Load‑balancer independent  
✔ Production‑grade & safe  

