```bash
bash antigravity-setup.sh
```

With no arguments it shows an arrow-key menu. You can also use the number keys 1 to 5, or `q` to quit.

| Option | What it does |
|---|---|
| 1. Install or update | Uses the tarball you already downloaded. If none is found, it stops and shows how to download it. |
| 2. Uninstall (keep my settings) | Removes the app, launcher, command and any old `~/Applications` copy. Your settings and login stay. |
| 3. Full uninstall | Does everything in option 2, and also deletes the settings, logs, cache and extensions. |
| 4. Status | Shows the version, launcher, sandbox permissions, running state, leftover data and any downloaded tarball. |
| 5. Exit | Quits without changing anything. |

**Skipping the menu:**

```bash
bash antigravity-setup.sh install
bash antigravity-setup.sh install --tarball ~/Downloads/"Antigravity IDE.tar.gz"
bash antigravity-setup.sh uninstall
bash antigravity-setup.sh purge -y
bash antigravity-setup.sh status
bash antigravity-setup.sh --help
```

**Safety:**
- Before any uninstall, it lists exactly what it will delete, with sizes, and asks you to confirm. `-y` skips that.
- It never runs as root.
- It only purges the apt package named `antigravity-ide`. If the separate `antigravity` apt package is installed, it warns you instead of removing it.

**One change from my earlier uninstall script:** this one only deletes paths specific to the IDE (`~/.config/Antigravity IDE`, `~/.antigravity-ide`, `~/.gemini/antigravity-ide`, plus its cache and share folders). The old script also removed the generic `~/.config/Antigravity` and `~/.gemini/antigravity` folders. Those may belong to the 2.0 desktop app or the CLI, so this version leaves them alone.
