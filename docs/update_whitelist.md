### Update Whitelist

> **Note on matching**: The check is **case-insensitive** (e.g., both `Sudo apt update...` and `sudo apt update...` are authorized) and **automatically normalizes double spaces**.

### 1. Debian / Ubuntu (`apt` / `apt-get`)
#### With `sudo` on both commands (or individual ones):
- `sudo apt update && sudo apt upgrade -y`
- `sudo apt update && sudo apt -y upgrade`
- `sudo apt update && sudo apt upgrade`
- `sudo apt update && sudo apt full-upgrade -y`
- `sudo apt update && sudo apt -y full-upgrade`
- `sudo apt update && sudo apt full-upgrade`
- `sudo apt update && sudo apt dist-upgrade -y`
- `sudo apt update && sudo apt -y dist-upgrade`
- `sudo apt update && sudo apt dist-upgrade`
- `sudo apt-get update && sudo apt-get upgrade -y`
- `sudo apt-get update && sudo apt-get -y upgrade`
- `sudo apt-get update && sudo apt-get upgrade`
- `sudo apt-get update && sudo apt-get dist-upgrade -y`
- `sudo apt-get update && sudo apt-get -y dist-upgrade`
- `sudo apt-get update && sudo apt-get dist-upgrade`
- `sudo apt update && sudo do-release-upgrade`
- `sudo apt update`
- `sudo apt upgrade -y`
- `sudo apt -y upgrade`
- `sudo apt upgrade`
- `sudo apt-get update`
- `sudo apt-get upgrade -y`
- `sudo apt-get -y upgrade`
- `sudo apt-get upgrade`

#### With `sudo` only on the first command:
- `sudo apt update && apt upgrade -y`
- `sudo apt update && apt -y upgrade`
- `sudo apt update && apt upgrade`
- `sudo apt-get update && apt-get upgrade -y`
- `sudo apt-get update && apt-get -y upgrade`
- `sudo apt-get update && apt-get upgrade`

#### Without `sudo`:
- `apt update && apt upgrade -y`
- `apt update && apt -y upgrade`
- `apt update && apt upgrade`
- `apt update && apt full-upgrade -y`
- `apt update && apt -y full-upgrade`
- `apt update && apt full-upgrade`
- `apt update && apt dist-upgrade -y`
- `apt update && apt -y dist-upgrade`
- `apt update && apt dist-upgrade`
- `apt-get update && apt-get upgrade -y`
- `apt-get update && apt-get -y upgrade`
- `apt-get update && apt-get upgrade`
- `apt-get update && apt-get dist-upgrade -y`
- `apt-get update && apt-get -y dist-upgrade`
- `apt-get update && apt-get dist-upgrade`
- `apt update && do-release-upgrade`
- `apt update`
- `apt upgrade -y`
- `apt -y upgrade`
- `apt upgrade`
- `apt-get update`
- `apt-get upgrade -y`
- `apt-get -y upgrade`
- `apt-get upgrade`

---

### 2. Fedora / RHEL / CentOS / Rocky / AlmaLinux (`dnf` / `yum`)
- `sudo dnf update -y`
- `sudo dnf update`
- `sudo dnf upgrade -y`
- `sudo dnf upgrade`
- `sudo dnf check-update && sudo dnf upgrade -y`
- `dnf update -y`
- `dnf update`
- `dnf upgrade -y`
- `dnf upgrade`
- `sudo yum update -y`
- `sudo yum update`
- `yum update -y`
- `yum update`

---

### 3. Arch Linux / EndeavourOS / Manjaro (`pacman`)
- `sudo pacman -Syu --noconfirm`
- `sudo pacman -Syu`
- `pacman -Syu --noconfirm`
- `pacman -Syu`

---

### 4. Alpine Linux (`apk`)
- `sudo apk update && sudo apk upgrade`
- `apk update && apk upgrade`

---

### 5. openSUSE / SUSE Linux (`zypper`)
- `sudo zypper update -y`
- `sudo zypper update`
- `sudo zypper dup -y`
- `sudo zypper dup`
- `zypper update -y`
- `zypper update`
- `zypper dup -y`
- `zypper dup`

---

### 6. Snap & Flatpak Packages
- `sudo snap refresh`
- `snap refresh`
- `flatpak update -y`
- `flatpak update`
- `sudo flatpak update -y`
- `sudo flatpak update`

---