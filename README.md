<div align="center">

<h1>ANTIGRAVITY IDE<br>LINUX SETUP</h1>

<p><b>Install, update, uninstall and check Google Antigravity IDE on Linux.</b><br>
One bash script. Animated terminal menu. Built for Kali, Debian and Ubuntu.</p>

<p>
  <img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-green.svg">
  <img alt="Shell: Bash" src="https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white">
  <img alt="Platform: Linux" src="https://img.shields.io/badge/Platform-Linux-FCC624?logo=linux&logoColor=black">
  <img alt="PRs welcome" src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg">
</p>

<p>
  <img alt="Kali Linux" src="https://img.shields.io/badge/Kali-Linux-557C94?logo=kalilinux&logoColor=white">
  <img alt="Debian based" src="https://img.shields.io/badge/Debian-based-A81D33?logo=debian&logoColor=white">
  <img alt="Ubuntu" src="https://img.shields.io/badge/Ubuntu-supported-E95420?logo=ubuntu&logoColor=white">
  <img alt="Architectures" src="https://img.shields.io/badge/Arch-x86__64%20%7C%20ARM64-blue">
</p>

<p>
  <img alt="Stars" src="https://img.shields.io/github/stars/zoro0x0/antigravity-ide-installer-linux?style=flat&logo=github">
<img alt="Issues" src="https://img.shields.io/github/issues/zoro0x0/antigravity-ide-installer-linux">
<img alt="Last commit" src="https://img.shields.io/github/last-commit/zoro0x0/antigravity-ide-installer-linux">
<img alt="Unofficial" src="https://img.shields.io/badge/Unofficial-not%20affiliated%20with%20Google-lightgrey">

</p>

<p>
  <a href="#quick-start">Quick start</a> |
  <a href="#commands">Commands</a> |
  <a href="#how-to-install-antigravity-ide-on-kali-linux">Install</a> |
  <a href="#how-to-uninstall-antigravity-ide-completely">Uninstall</a> |
  <a href="#troubleshooting">Troubleshooting</a> |
  <a href="#faq">FAQ</a>
</p>

</div>

---

Unofficial installer and uninstaller for **Google Antigravity IDE** on **Kali Linux, Debian and Ubuntu**.

One bash script with an animated terminal menu to install, update, uninstall and check Antigravity IDE.

> **Disclaimer:** This project is not affiliated with, endorsed by, or sponsored by Google. "Antigravity" is a Google product and trademark. This script does not modify or redistribute Google's software. You download the official tarball yourself, and the script only installs it.

---

## Quick start

```bash
git clone https://github.com/zoro0x0/antigravity-ide-installer-linux.git
cd antigravity-ide-linux-setup

# 1. Download the Antigravity IDE tarball for Linux from the official site:
#    https://antigravity.google/download
#    Save it to ~/Downloads

# 2. Run the menu
bash antigravity-setup.sh
```

You will see a menu you can drive with the arrow keys (or number keys 1 to 5):

| Option | What it does |
|---|---|
| 1. Install or update | Installs from the tarball you downloaded. Stops with help if it is missing. |
| 2. Uninstall (keep my settings) | Removes the app, launcher and command. Keeps your settings, login and extensions. |
| 3. Full uninstall | Removes the app and all its settings, logs, cache and extensions. |
| 4. Status | Shows what is installed on your system. |
| 5. Exit | Quits without changing anything. |

---

## Commands

Skip the menu by passing a command:

```bash
bash antigravity-setup.sh install                                   # auto-find the tarball
bash antigravity-setup.sh install --tarball ~/Downloads/"Antigravity IDE.tar.gz"
bash antigravity-setup.sh uninstall                                 # keep settings
bash antigravity-setup.sh purge                                     # remove everything
bash antigravity-setup.sh status
bash antigravity-setup.sh --help
```

Options:

| Option | Meaning |
|---|---|
| `--tarball FILE` | Use a specific tarball instead of auto-detecting |
| `-y`, `--yes` | Do not ask for confirmation |
| `--no-color` | Plain output with no animation (useful for logs and CI) |
| `-h`, `--help` | Show help |

---

## How to install Antigravity IDE on Kali Linux

The script works in 3 steps:

1. **Check the downloaded file.** It looks in `~/Downloads`, `~/Desktop` and the current folder for an Antigravity tarball. If none is found, it stops and tells you where to download it. It also checks the archive is complete and is the IDE tarball (not the 2.0 desktop app or the CLI).
2. **Install.** It installs the runtime libraries, extracts the tarball, and copies it to `/opt/antigravity-ide/Antigravity-IDE`. The folder name has no space, which avoids a known problem where the IDE fails to start from a path containing a space. It sets `chrome-sandbox` to `root:root` with mode `4755`.
3. **Integrate and verify.** It creates the `antigravity-ide` command, the app-menu launcher and the icon, then verifies everything.

After install, start it with:

```bash
antigravity-ide
```

or open **Antigravity IDE** from your applications menu.

### What gets installed

| Path | Purpose |
|---|---|
| `/opt/antigravity-ide/Antigravity-IDE` | The app |
| `/opt/antigravity-ide.previous` | Backup of the previous version (after an update) |
| `/usr/local/bin/antigravity-ide` | Command symlink |
| `/usr/share/applications/antigravity-ide.desktop` | App-menu launcher |
| `/usr/share/icons/hicolor/512x512/apps/antigravity-ide.png` | Icon |

Your home folder is not touched during install.

---

## How to uninstall Antigravity IDE completely

```bash
bash antigravity-setup.sh purge
```

Before deleting anything, the script lists every path it will remove, with sizes, and asks you to confirm.

It removes, when present:

- The system install under `/opt/antigravity-ide` and the command, launcher and icon
- An old manual install at `~/Applications/antigravity-ide` and related user launchers
- The `antigravity-ide` apt package, if you installed it that way
- With `purge` only: `~/.config/Antigravity IDE`, `~/.antigravity-ide`, `~/.gemini/antigravity-ide`, and its cache and share folders

It does **not** touch data that may belong to other Antigravity products (the 2.0 desktop app or the CLI), such as `~/.config/Antigravity`. It also does not remove the separate `antigravity` apt package, and warns you if it is installed.

If you signed in with a Google account, also revoke access at **myaccount.google.com > Security > Third-party apps and services**.

---

## Troubleshooting

**"Tarball not found."** Download the Antigravity IDE tarball for Linux from https://antigravity.google/download, save it in `~/Downloads`, and run the script again. If it is somewhere else, use `--tarball /path/to/file.tar.gz`.

**"This does not look like the Antigravity IDE tarball."** You may have downloaded the 2.0 desktop app or the CLI. Download the **Antigravity IDE** build instead.

**A download is still in progress.** The script found a `.crdownload` or `.part` file. Wait for the download to finish and run it again.

**Black window or blank screen.** Start it from a terminal with GPU acceleration off:

```bash
antigravity-ide --disable-gpu
```

On Wayland, also try:

```bash
ELECTRON_OZONE_PLATFORM_HINT=x11 antigravity-ide --disable-gpu
```

**It closes immediately.** Run `antigravity-ide` from a terminal to see the error. Check the sandbox helper permissions:

```bash
stat -c '%U:%G:%a' /opt/antigravity-ide/Antigravity-IDE/chrome-sandbox   # expect root:root:4755
```

You can also run `bash antigravity-setup.sh status` to see this check. Avoid using `--no-sandbox` as your normal launcher.

**Version check over SSH fails.** The IDE is a graphical app and needs a desktop session. Use `status` instead of `antigravity-ide --version` on a headless machine.

**The script failed.** A log is saved to `~/antigravity-setup-failed.log`. Include it when you open an issue.

---

## Requirements

- Debian-based Linux with `apt` (Kali, Debian, Ubuntu and derivatives)
- x86_64 or ARM64
- `sudo` access, and a normal (non-root) user
- About 2 GB of free disk space
- A graphical desktop session to run the IDE

---

## FAQ

**Why not use the apt repository?**
Google's APT repository still exists, but the newest package it provides is an older 1.x build. The current IDE is distributed as a Linux tarball, so this script installs from that.

**Why does the script not download the file for me?**
By design: you download the official tarball yourself from Google, so you know exactly what is being installed.

**Will it overwrite my settings on update?**
No. Updating only replaces the app under `/opt`. Your settings live in your home folder and are left alone. The previous version is kept at `/opt/antigravity-ide.previous`.

**Can I run it as root?**
No. Run it as your normal user. It calls `sudo` only for the steps that need it.

---

## Tested on

Fill this in after testing:

| Distro | Version | Architecture | Result |
|---|---|---|---|
| Kali Linux | | x86_64 | |
| Ubuntu | | x86_64 | |
| Debian | | x86_64 | |

---

## Contributing

Issues and pull requests are welcome. When reporting a bug, include your distro and version, CPU architecture, the command you ran, and `~/antigravity-setup-failed.log` if it exists.

## License

MIT. See [LICENSE](LICENSE).

---

**Keywords:** Antigravity IDE, Google Antigravity, install Antigravity on Kali Linux, uninstall Antigravity IDE, Antigravity IDE Linux, Antigravity IDE Ubuntu, Antigravity IDE Debian, Antigravity IDE not opening, Antigravity chrome-sandbox, antigravity-ide command not found
