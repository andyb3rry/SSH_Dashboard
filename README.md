# SSH Dashboard

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Cloudflare Zero Trust](https://img.shields.io/badge/Cloudflare-Zero%20Trust-F38020?style=for-the-badge&logo=cloudflare&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android-green?style=for-the-badge&logo=android&logoColor=white)

**SSH Dashboard** is a modern, vibe-coded server management dashboard and interactive SSH terminal built with Flutter. It allows system administrators and developers to monitor real-time Linux telemetry, manage server power states, and securely connect via terminal—including native support for **Cloudflare Zero Trust Tunnels via Service Tokens**.

---

## ⬇️ Download
<div align="center">
  <a href="https://github.com/andyb3rry/SSH_Dashboard/releases">
    <img src="https://user-images.githubusercontent.com/69304392/148696068-0cfea65d-b18f-4685-82b5-329a330b1c0d.png"
    alt="Get it on GitHub" align="middle" height="80" /></a>
  <a href="https://github.com/ImranR98/Obtainium/tree/main">
    <img src="https://github.com/ImranR98/Obtainium/raw/main/assets/graphics/badge_obtainium.png" alt="Get it on Obtainium" align="middle" height="80" /></a>
</div>

---

## 📱 Screenshots

| Server List | Real-Time Resources | Active Processes |
| :---: | :---: | :---: |
| <img src="https://github.com/user-attachments/assets/cd3afbd5-2e74-46e8-ac1f-d72a5dfd4087" width="240" alt="Server List" /> | <img src="https://github.com/user-attachments/assets/02cf8f98-6cbf-47f5-b3a5-2701edd8f8f1" width="240" alt="Resources" /> | <img src="https://github.com/user-attachments/assets/e932b2bc-f1cc-4d63-b4e7-fa526efc13bc" width="240" alt="Processes" /> |

| SSH Terminal | Docker Management | System Management|
| :---: | :---: | :---: |
| <img src="https://github.com/user-attachments/assets/678767aa-0563-4f42-b7b7-5022854b3f1a" width="240" alt="Terminal" /> | <img src="https://github.com/user-attachments/assets/9b4d5e04-88e6-467e-9870-7a0e9dc8e944" width="240" alt="Docker Containers" /> | <img alt="powermenu" src="https://github.com/user-attachments/assets/a3532208-2ef7-47dd-876b-49746b670ff3" width="240" /><br /> <img src="https://github.com/user-attachments/assets/2c4d3173-9511-4823-bccf-7eda1af6f127" width="240" alt="System Control" /> |

---

## ✨ Key Features

- **📊 Real-Time Resource Monitoring**: Live telemetry graphs tracking CPU load, RAM consumption, network I/O speeds, and disk usage.
- **🐳 Docker Container Management**: Run, stop, restart, and remove Docker containers.
- **🕘 Cron Job Management**: Add, edit, delete, run and check the last execution of the cron jobs on your server.
- **🖥️ Terminal**: Built-in full VT100/Xterm compatible SSH terminal using `dartssh2`, supporting interactive commands, sudo, and custom scripts.
- **⚡ Power Management**: Instant one-click triggers for system `Reboot`, `Shutdown`, system updates (`apt/dnf update & upgrade`), and local/remote commands.
- **🔐 Cloudflare Zero Trust Native Integration**: Seamlessly connect to servers hidden behind Cloudflare Tunnels over WebSockets. Uses non-expiring **Service Tokens**.
- **🛡️ Enterprise Secure Storage**: Passwords, SSH private keys, and Cloudflare Client Secrets are stored natively in Android's KeyStore.

---

## 🏗️ Cloudflare Zero Trust Setup

SSH Dashboard allows you to connect securely to your remote Linux servers via **Cloudflare Tunnels** (`cloudflared`) without opening port 22 to the public internet. 

To eliminate interactive web browser logins (which expire frequently and are clunky on mobile devices), SSH Dashboard uses **Cloudflare Service Tokens**. The application upgrades the HTTP request to a WebSocket (`wss://`) over `/cdn-cgi/access/cli` while passing `CF-Access-Client-Id` and `CF-Access-Client-Secret` headers directly during the handshake.

### 📋 Step-by-Step Configuration Guide

#### Step 1: Install & Run `cloudflared` on Your Server
* Follow the [Official Cloudflare Docs](https://developers.cloudflare.com/tunnel/setup/) to set up and run a secure tunnel on your machine.

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
3. Name your token (e.g., `ssh-dashboard-app`).
4. Set **Token Duration** to **Non-expiring** (or your desired lifespan).
5. Click **Generate Token**.
6. > ⚠️ **IMPORTANT**: Immediately copy and save the **Client ID** (`CF-Access-Client-Id`) and **Client Secret** (`CF-Access-Client-Secret`). *You will not be able to see the secret again after closing the window.*

#### Step 4: Link the Service Token to Your Access Policy
1. Return to the **Policies** tab of the application you created in Step 2.
2. Add a new policy:
   - **Policy Name**: `Allow Service Token SSH`
   - **Action**: `Service Auth` (or `Allow`)
3. Under **Configure rules** -> **Include**, select:
   - **Selector**: `Service Token`
   - **Value**: Select the Service Token you created (`ssh-dashboard-app`).
4. Click **Next** -> **Add application** to save.

#### Step 5: Configure SSH Dashboard
1. Open the **SSH Dashboard** mobile app and click **Add Server** (`+`).
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
- **Biometric & OS Protection**: Optional biometric/PIN authentication on app resume.
- **SSH MitM Prevention**: Implements Trust-On-First-Use (TOFU) host key verification, blocking connections if the server's fingerprint unexpectedly changes.
- **Sudo Obfuscation**: Root commands and passwords are piped directly through `stdin`, remaining completely invisible to the server's process list (`ps aux` or `/proc`).
- **Command Injection Hardening**: Implements a dedicated command validation engine that actively monitors inputs across the Server Profile, Docker Management, and Cron Manager. It blocks dangerous execution patterns, prevents root boot persistence exploits, restricts untrusted directories, and disables execution if risks are detected.
---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
