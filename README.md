# SSH Dashboard 

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Cloudflare Zero Trust](https://img.shields.io/badge/Cloudflare-Zero%20Trust-F38020?style=for-the-badge&logo=cloudflare&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android-green?style=for-the-badge&logo=android&logoColor=white)

**SSH Dashboard** is a modern, vibe-coded server management dashboard and interactive SSH terminal built with Flutter. It allows system administrators and developers to monitor real-time Linux telemetry, manage server power states, and securely connect via terminal—including native support for **Cloudflare Zero Trust Tunnels via Service Tokens**.

---

## ✨ Key Features

- **📊 Real-Time Resource Monitoring**: Live telemetry graphs tracking CPU load per logical core, RAM consumption, network I/O speeds (`netstat`/`proc`), and disk usage (`df -h`).
- **🐳 Docker Container Management**: Run, stop, restart, and remove Docker containers on your server.
- **🕘 Cron Job Management**: Add, edit, delete, and run cron jobs on your server.
- **🖥️ Terminal**: Built-in full VT100/Xterm compatible SSH terminal using `dartssh2`, supporting interactive commands, sudo, and custom scripts.
- **⚡ Power Management**: Instant one-click triggers for system `Reboot`, `Shutdown`, system updates (`apt/dnf update & upgrade`), and local/remote commands.
- **🔐 Cloudflare Zero Trust Native Integration**: Seamlessly connect to servers hidden behind Cloudflare Tunnels (`cloudflared`) over WebSockets (`wss://`) without opening web browsers or dealing with expiring session cookies. Uses non-expiring **Service Tokens**.
- **🛡️ Enterprise Secure Storage**: Passwords, SSH private keys, and Cloudflare Client Secrets are stored natively in Android's KeyStore.

---

## 🏗️ Cloudflare Zero Trust Setup

Server Commander SSH allows you to connect securely to your remote Linux servers via **Cloudflare Tunnels** (`cloudflared`) without opening port 22 to the public internet. 

To eliminate interactive web browser logins (which expire frequently and are clunky on mobile devices), Server Commander SSH uses **Cloudflare Service Tokens**. The application upgrades the HTTP request to a WebSocket (`wss://`) over `/cdn-cgi/access/cli` while passing `CF-Access-Client-Id` and `CF-Access-Client-Secret` headers directly during the handshake.

### 📋 Step-by-Step Configuration Guide

#### Step 1: Install & Run `cloudflared` on Your Server ([Docs](https://developers.cloudflare.com/tunnel/setup/))

#### Step 2: Create an Application in Cloudflare Zero Trust
1. Log into the **Cloudflare Zero Trust Dashboard** ([one.dash.cloudflare.com](https://one.dash.cloudflare.com/)).
2. Navigate to **Access** -> **Applications** -> **Add an Application**.
3. Select **Self-hosted**.
4. Set the **Application Name** (e.g., `SSH Dashboard Server`) and **Session Duration** (e.g., `24 hours` or `No expiration`).
5. In **Application Domain**, enter the subdomain mapped to your tunnel:
   - Subdomain: `ssh`
   - Domain: `yourdomain.com`
6. Click **Next** to proceed to Policies.

#### Step 3: Create a Service Token (`Client ID` + `Client Secret`)
1. In another tab of the Cloudflare Zero Trust dashboard, navigate to **Access** -> **Service Auth** -> **Service Tokens**.
2. Click **Create Service Token**.
3. Name your token (e.g., `server-commander-app`).
4. Set **Token Duration** to **Non-expiring** (or your desired lifespan).
5. Click **Generate Token**.
6. **IMPORTANT**: Immediately copy and save the **Client ID** (`CF-Access-Client-Id`) and **Client Secret** (`CF-Access-Client-Secret`). *You will not be able to see the secret again after closing the window.*

#### Step 4: Link the Service Token to Your Access Policy
1. Return to the **Policies** tab of the application you created in Step 2.
2. Add a new policy:
   - **Policy Name**: `Allow Service Token SSH`
   - **Action**: `Service Auth` (or `Allow`)
3. Under **Configure rules** -> **Include**, select:
   - **Selector**: `Service Token`
   - **Value**: Select the Service Token you created (`server-commander-app`).
4. Click **Next** -> **Add application** to save.

#### Step 5: Configure Server Commander SSH
1. Open **Server Commander SSH** and click **Add Server** (`+`).
2. Enter your server credentials:
   - **Host / IP**: `ssh.yourdomain.com`
   - **Port**: `443` (or `22`)
   - **Username**: `root` (or your Linux username)
   - **Password / Private Key**: Your server authentication method.
3. Scroll down to **Cloudflare Zero Trust Tunnel** and **enable the toggle**.
4. Enter your Service Token credentials:
   - **CF-Access-Client-Id**: Paste your `Client ID` (e.g., `123456789.access`).
   - **CF-Access-Client-Secret**: Paste your `Client Secret` (e.g., `a1b2c3d4e5...`).
5. Click **Save Profile**. You can now connect and monitor your server instantly over WebSockets!

---

## 🔒 Security
- **No Cleartext Storage**: All sensitive fields are isolated from standard preference files and written exclusively to encrypted platform storage (`flutter_secure_storage`).
- **Automatic Sanitization**: If existing server profiles contain legacy credentials in `SharedPreferences`, the app automatically migrates them to secure storage upon startup and sanitizes the local JSON payload.
- **Biometric & OS Protection**: Enforces biometric/PIN authentication on app resume and blocks screen capturing (`FLAG_SECURE` / disabled Android backups) to prevent data leaks.
- **SSH MitM Prevention**: Implements Trust-On-First-Use (TOFU) host key verification, blocking connections if the server's fingerprint unexpectedly changes.
- **Sudo Obfuscation**: Root commands and passwords are piped directly through `stdin`, remaining completely invisible to the server's process list (`ps aux` or `/proc`).
- **Injection Hardening**: Strict regex validation and POSIX boundary checks prevent arbitrary command injection during Docker and process management.

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
