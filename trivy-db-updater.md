# 🛡️ Trivy Database Updater

**📘 Installation & Operations Guide** · Jenkins Build Server · RHEL 9

> ✅ **Goal:** Keep Trivy Vulnerability and Java databases updated in the shared cache so Jenkins scans avoid repeated database downloads.

| 🖥️ Server | 🧰 Trivy executable | 📦 Shared cache | ⏰ Schedule |
|:--|:--|:--|:--|
| `ngd-dc2-cicd-build1` | `/usr/bin/trivy` | `/var/cache/trivy` | Every 6 hours |

## 🎯 Purpose

Automatically refresh the **Trivy Vulnerability DB** and **Trivy Java DB** on the Jenkins build server (`ngd-dc2-cicd-build1`) so Jenkins jobs can reuse the databases in `/var/cache/trivy` without downloading them during every image scan.

**✨ Key capabilities**

The updater:

- Uses `/usr/bin/trivy` and a shared cache at `/var/cache/trivy`.
- Supports an **optional corporate HTTP/HTTPS proxy**: a nonempty `PROXY_URL` enables it; an empty value disables all inherited proxy settings for the updater.
- Updates both vulnerability and Java databases, logs results and returns a nonzero exit code on failure.
- Uses `flock` to prevent overlapping **updater** executions.
- Works in cron; when run interactively, follow the logfile to observe progress.

> ⚠️ **Concurrency:** The lock prevents simultaneous updater jobs, **not** collisions between a database update and an active Jenkins scan. Schedule updates away from busy scan windows or coordinate the scanner and updater using a shared lock.

## 🧩 Complete Bash Script

📁 **Script location:** `/usr/local/sbin/update-trivy-db.sh`

Save the complete script below:

```bash
#!/usr/bin/env bash
# Trivy Vulnerability DB + Java DB cron updater
set -Eeuo pipefail

TRIVY_BIN="/usr/bin/trivy"
CACHE_DIR="/var/cache/trivy"
LOG_FILE="/var/log/trivy-db-update.log"
LOCK_FILE="/var/lock/trivy-db-update.lock"

# Optional proxy. Leave blank for direct connections.
PROXY_URL=""
NO_PROXY_HOSTS="localhost,127.0.0.1,registry.nagad.com.bd"
UPDATE_TIMEOUT="30m"

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin"
umask 002

# Clear inherited proxy settings so blank really means direct access.
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy
unset NO_PROXY no_proxy
if [[ -n "$PROXY_URL" ]]; then
    export HTTP_PROXY="$PROXY_URL" HTTPS_PROXY="$PROXY_URL"
    export http_proxy="$PROXY_URL" https_proxy="$PROXY_URL"
    export NO_PROXY="$NO_PROXY_HOSTS" no_proxy="$NO_PROXY_HOSTS"
fi

# Cron-compatible logging. Use tail -f to watch progress.
exec >> "$LOG_FILE" 2>&1
log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$*"; }

log "========== Trivy DB update started =========="
log "Proxy: $([[ -n "$PROXY_URL" ]] && echo enabled || echo disabled)"

if [[ ! -x "$TRIVY_BIN" ]]; then
    log "ERROR: Trivy not executable at $TRIVY_BIN"
    exit 1
fi
if ! mkdir -p "$CACHE_DIR"; then
    log "ERROR: Cannot create cache directory $CACHE_DIR"
    exit 1
fi

# Acquire a non-blocking exclusive updater lock.
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    log "INFO: Another update is running. Skipping this run."
    exit 0
fi

log "Trivy: $("$TRIVY_BIN" --version | head -n 1)"
log "Cache: $CACHE_DIR"
FAILED=0

log "Updating Vulnerability DB ..."
if timeout "$UPDATE_TIMEOUT" "$TRIVY_BIN" image \
    --cache-dir "$CACHE_DIR" --download-db-only --no-progress; then
    log "SUCCESS: Vulnerability DB update completed"
else
    log "ERROR: Vulnerability DB update failed"
    FAILED=1
fi

log "Updating Java DB ..."
if timeout "$UPDATE_TIMEOUT" "$TRIVY_BIN" image \
    --cache-dir "$CACHE_DIR" --download-java-db-only --no-progress; then
    log "SUCCESS: Java DB update completed"
else
    log "ERROR: Java DB update failed"
    FAILED=1
fi

if [[ "$FAILED" -eq 0 ]]; then
    log "SUCCESS: All database updates completed"
else
    log "ERROR: One or more database updates failed"
fi
log "========== Trivy DB update finished =========="
exit "$FAILED"
```

## 🛠️ Installation & Configuration

### 1. 🔍 Verify Trivy

```bash
command -v trivy       # Expected: /usr/bin/trivy
trivy --version
```

### 2. 📝 Create the Script & Set Permissions

```bash
sudo vi /usr/local/sbin/update-trivy-db.sh
# Paste the script above and save.
sudo chmod 750 /usr/local/sbin/update-trivy-db.sh
sudo bash -n /usr/local/sbin/update-trivy-db.sh
```

### 3. 🌐 Configure Optional Proxy

Edit the `PROXY_URL` line at the beginning of the script:

```bash
PROXY_URL=""  # Use corporate proxy
# OR
PROXY_URL=""                           # Connect directly
```

> 💡 **Proxy logic:** A populated `PROXY_URL` enables the proxy; `PROXY_URL=""` unsets inherited proxy variables and uses direct access.

Add internal hostnames to `NO_PROXY_HOSTS` if necessary. Proxy credentials, if required, should **not** be embedded in a world-readable script.

### 4. 🔐 Configure Execution Permissions

🔸 **Option A — Root cron:** Run the updater as root; ensure the Jenkins scanning user can read the updated files in `/var/cache/trivy`. Root-created files may prevent the Jenkins user from writing to the same cache.

✅ **Option B — Dedicated non-root cron (recommended):** Use the account already running Jenkins scans, or a dedicated service account that has compatible read/write access to the shared cache. That account must also be able to write to the script's log and lock paths.

For example, when the updater runs as `devops`:

```bash
# As root; only do this if these locations are dedicated to this updater.
install -d -o devops -g devops -m 750 /var/log/trivy
install -d -o devops -g devops -m 750 /var/lock/trivy
```

Change these script variables:

```bash
LOG_FILE="/var/log/trivy/trivy-db-update.log"
LOCK_FILE="/var/lock/trivy/trivy-db-update.lock"
```

Check the existing cache owner **before** making permission changes:

```bash
ls -ld /var/cache/trivy
ps -eo user,pid,args | grep -E '[j]enkins|[a]gent.jar'
```

Provision the cache directory for the actual Jenkins/build account with appropriately restricted group permissions. Avoid `chmod 777` or blindly changing ownership of a cache used by active builds. On RHEL with SELinux Enforcing, check labels and audit logs if access is denied even though Unix permissions appear correct.

If `/etc/cron.allow` exists, root must add the intended non-root account to it. Preserve existing entries:

```bash
sudo grep -qxF 'devops' /etc/cron.allow || echo 'devops' | sudo tee -a /etc/cron.allow
```

### 5. 🧪 Test Manually

Run as the **same user** that will own the cron job:

```bash
/usr/local/sbin/update-trivy-db.sh
echo "Exit code: $?"
```

The script logs to a file instead of displaying output on screen. To watch activity from another shell:

```bash
tail -f /var/log/trivy-db-update.log
# Or, with the non-root paths above:
tail -f /var/log/trivy/trivy-db-update.log
```

> ✅ **Expected success log:** `SUCCESS: All database updates completed`

Verify the cache:

```bash
ls -lah /var/cache/trivy/db/
ls -lah /var/cache/trivy/java-db/
```

### 6. ⏰ Configure Cron

Open `crontab -e` as the **chosen execution user**. For a six-hour schedule:

```cron
15 */6 * * * /usr/local/sbin/update-trivy-db.sh
```

Runs at 00:15, 06:15, 12:15 and 18:15 **server local time**. If cron emails are unwanted, redirect its output to `/dev/null` (the script still logs internally):

```cron
15 */6 * * * /usr/local/sbin/update-trivy-db.sh >/dev/null 2>&1
```

Verify:

```bash
crontab -l
sudo systemctl status crond
sudo journalctl -u crond --since '1 hour ago'
```

## 🔗 Jenkins Shared Library Integration

Once **both databases are populated and kept current**, include these options in Jenkins' Trivy scan command:

```bash
--cache-dir /var/cache/trivy \
--skip-db-update \
--skip-java-db-update
```

> ⚠️ **Important:** The `--skip-db-update` switch does **not** skip Java DB downloads; `--skip-java-db-update` is needed separately. Both switches depend on the updater maintaining usable local cache data. Do not keep skipping updates indefinitely after updater failures; monitor the log and database age.

## 🩺 Troubleshooting

| Symptom | Check |
| --- | --- |
| Script appears silent | `tail -f` the configured logfile; output is redirected. |
| `Permission denied` | Verify ownership/mode of cache, logfile, lockfile, and script; check SELinux where applicable. |
| Proxy errors | Confirm `PROXY_URL`, `NO_PROXY_HOSTS`, and outbound access to Trivy DB registries. |
| Update skipped | Another updater holds `LOCK_FILE`; check updater processes. |
| Jenkins still downloads Java DB | Confirm its command includes `--skip-java-db-update` and cache directory matches. |
| Cron doesn't execute | Check `crond`, `crontab -l`, `/etc/cron.allow`, and `journalctl -u crond`. |

## 📋 Operational Checklist

- [ ] Check `/var/log/trivy-db-update.log` (or your configured alternative) after the first scheduled execution.
- [ ] Configure log rotation and monitoring/alerting for stale databases and nonzero updater exit codes.
- [ ] The script intentionally doesn't use `--force-db-update`; normal cache-age behavior avoids unnecessary downloads.
- [ ] Each update has a 30-minute timeout and the lock avoids updater overlap; neither guarantees uninterrupted scanning during a concurrent cache update.
