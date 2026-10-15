#!/usr/bin/env bash
# antigravity-setup.sh
# Install, uninstall and check Google Antigravity IDE on Debian-based Linux (Kali, Debian, Ubuntu).
# Run it with no arguments for an interactive menu, or pass a command (see --help).
# Run as your normal user (not root). sudo is used only where needed.

set -euo pipefail
shopt -s nullglob
export LC_NUMERIC=C

APP_NAME="Antigravity IDE"
INSTALL_ROOT="/opt/antigravity-ide"
INSTALL_DIR="Antigravity-IDE"
BIN_LINK="/usr/local/bin/antigravity-ide"
DESKTOP_FILE="/usr/share/applications/antigravity-ide.desktop"
ICON_FILE="/usr/share/icons/hicolor/512x512/apps/antigravity-ide.png"
DOWNLOAD_PAGE="https://antigravity.google/download"

usage() {
  cat <<'EOF'
Usage: bash antigravity-setup.sh [command] [options]

Commands:
  (none)       Interactive menu
  install      Install or update from a tarball you already downloaded
  uninstall    Remove the app, keep your settings and login
  purge        Remove the app and all its settings, logs and extensions
  status       Show what is installed

Options:
  --tarball FILE   Use this tarball for install (default: auto-find in ~/Downloads, ~/Desktop, here)
  -y, --yes        Do not ask for confirmation
  --no-color       Plain output, no animation
  -h, --help       Show this help

Get the tarball first: https://antigravity.google/download (Antigravity IDE for Linux)
EOF
}

# ---------- arguments ----------
CMD=""; TARBALL=""; YES=0; NOCOLOR=0
while [ $# -gt 0 ]; do
  case "$1" in
    install|uninstall|purge|status) CMD="$1"; shift ;;
    --tarball) [ $# -ge 2 ] || { echo "--tarball needs a file"; exit 1; }; TARBALL="$2"; shift 2 ;;
    -y|--yes) YES=1; shift ;;
    --no-color) NOCOLOR=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1 (try --help)"; exit 1 ;;
  esac
done

# ---------- colors and terminal ----------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "$NOCOLOR" = 0 ]; then
  TTY=1
  R=$'\e[0m'; B=$'\e[1m'; D=$'\e[2m'
  RED=$'\e[38;5;203m'; GRN=$'\e[38;5;78m'; YEL=$'\e[38;5;221m'
  CYN=$'\e[38;5;45m'; MAG=$'\e[38;5;177m'
else
  TTY=0; R=""; B=""; D=""; RED=""; GRN=""; YEL=""; CYN=""; MAG=""
fi

WORK=$(mktemp -d /var/tmp/antigravity-setup.XXXXXX)
LOG="$WORK/setup.log"
: > "$LOG"
SUDO_PID=""
STEP=0
TOTAL=1

cleanup() {
  local rc=$?
  if [ "$TTY" = 1 ]; then printf '\e[?25h'; fi
  if [ -n "$SUDO_PID" ]; then kill "$SUDO_PID" 2>/dev/null || true; fi
  rm -rf "$WORK"
  exit $rc
}
trap cleanup EXIT
trap 'printf "\n"; echo "Interrupted."; exit 130' INT TERM
if [ "$TTY" = 1 ]; then printf '\e[?25l'; fi

# ---------- output helpers ----------
phase() { STEP=$((STEP + 1)); printf '\n%s%s[%d/%d]%s %s%s%s\n' "$B" "$MAG" "$STEP" "$TOTAL" "$R" "$B" "$1" "$R"; }
ok()    { printf '  %s✔%s %s\n' "$GRN" "$R" "$*"; }
warn()  { printf '  %s!%s %s\n' "$YEL" "$R" "$*"; }
info()  { printf '  %s•%s %s\n' "$CYN" "$R" "$*"; }
die()   { printf '\n  %s✘ %s%s\n\n' "$RED" "$*" "$R" >&2; exit 1; }
human() { awk -v b="$1" 'BEGIN{printf "%.1f", b/1048576}'; }
exists() { [ -e "$1" ] || [ -L "$1" ]; }
psize() { du -sh -- "$1" 2>/dev/null | cut -f1 || true; }

show_failure() {
  cp "$LOG" "$HOME/antigravity-setup-failed.log" 2>/dev/null || true
  if [ -s "$LOG" ]; then
    printf '  %s--- last log lines ---%s\n' "$D" "$R"
    tail -n 12 "$LOG" | sed 's/^/    /'
    printf '  %sFull log: ~/antigravity-setup-failed.log%s\n' "$D" "$R"
  fi
}

banner() {
  local title="A N T I G R A V I T Y   I D E" pal=(51 45 39 33 63 99 135 171 207) i ch c
  printf '\n  %s╭──────────────────────────────────────────────╮%s\n' "$D" "$R"
  printf '  %s│%s   ' "$D" "$R"
  for ((i = 0; i < ${#title}; i++)); do
    ch="${title:i:1}"; c="${pal[i % ${#pal[@]}]}"
    if [ "$TTY" = 1 ]; then printf '\e[1;38;5;%sm%s%s' "$c" "$ch" "$R"; sleep 0.03; else printf '%s' "$ch"; fi
  done
  printf '%*s%s│%s\n' 14 '' "$D" "$R"
  printf '  %s│%s%-46s%s│%s\n' "$D" "$R" "   Setup manager: install, update, uninstall" "$D" "$R"
  printf '  %s╰──────────────────────────────────────────────╯%s\n' "$D" "$R"
}

# Run a command in the background with a spinner. Output goes to the log.
FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
run_step() {
  local msg="$1"; shift
  local rc=0 i=0 start=$SECONDS pid
  if [ "$TTY" = 0 ]; then
    printf '  [..] %s\n' "$msg"
    "$@" >>"$LOG" 2>&1 || rc=$?
    if [ $rc -eq 0 ]; then printf '  [ok] %s\n' "$msg"; return 0; fi
    printf '  [fail] %s\n' "$msg"; show_failure; exit 1
  fi
  "$@" >>"$LOG" 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r\e[2K  %s%s%s %s %s(%ss)%s' "$CYN" "${FRAMES[i % 10]}" "$R" "$msg" "$D" "$((SECONDS - start))" "$R"
    i=$((i + 1)); sleep 0.08
  done
  wait "$pid" || rc=$?
  if [ $rc -eq 0 ]; then
    printf '\r\e[2K  %s✔%s %s %s(%ss)%s\n' "$GRN" "$R" "$msg" "$D" "$((SECONDS - start))" "$R"
  else
    printf '\r\e[2K  %s✘%s %s\n' "$RED" "$R" "$msg"
    show_failure
    exit 1
  fi
}

confirm() {
  local ans
  if [ "$YES" = 1 ]; then return 0; fi
  if [ ! -t 0 ]; then die "Confirmation needed but no terminal. Re-run with -y."; fi
  if [ "$TTY" = 1 ]; then printf '\e[?25h'; fi
  read -r -p "  $1 [y/N] " ans || ans="n"
  if [ "$TTY" = 1 ]; then printf '\e[?25l'; fi
  case "$ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

require_user() {
  if [ "$(id -u)" -eq 0 ]; then die "Do not run as root. Use your normal user; sudo is used where needed."; fi
  command -v sudo >/dev/null 2>&1 || die "sudo is required."
}

ensure_sudo() {
  if [ -n "$SUDO_PID" ]; then return 0; fi
  info "Administrator access is needed"
  sudo -v || die "sudo authentication failed."
  ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) >/dev/null 2>&1 &
  SUDO_PID=$!
}

# ---------- interactive menu ----------
MENU_ITEMS=(); MENU_DESC=(); CHOICE=0
choose() {
  local sel=0 n=${#MENU_ITEMS[@]} i key rest drawn=0
  while true; do
    if [ $drawn -eq 1 ]; then printf '\e[%dA' "$((n * 2))"; fi
    for ((i = 0; i < n; i++)); do
      if [ $i -eq $sel ]; then
        printf '\r\e[2K  %s%s❯ %d. %s%s\n' "$CYN" "$B" "$((i + 1))" "${MENU_ITEMS[i]}" "$R"
      else
        printf '\r\e[2K    %d. %s\n' "$((i + 1))" "${MENU_ITEMS[i]}"
      fi
      printf '\r\e[2K       %s%s%s\n' "$D" "${MENU_DESC[i]}" "$R"
    done
    drawn=1
    IFS= read -rsn1 key || exit 1
    case "$key" in
      $'\e')
        rest=""; read -rsn2 -t 0.05 rest || rest=""
        case "$rest" in
          '[A') sel=$(((sel - 1 + n) % n)) ;;
          '[B') sel=$(((sel + 1) % n)) ;;
        esac ;;
      k) sel=$(((sel - 1 + n) % n)) ;;
      j) sel=$(((sel + 1) % n)) ;;
      '') break ;;
      [1-9]) if [ "$key" -le "$n" ]; then sel=$((key - 1)); break; fi ;;
      q|Q) sel=$((n - 1)); break ;;
    esac
  done
  CHOICE=$sel
}

interactive_menu() {
  MENU_ITEMS=("Install or update" "Uninstall (keep my settings)" "Full uninstall (remove everything)" "Status" "Exit")
  MENU_DESC=(
    "Use the tarball you downloaded. Stops with help if it is missing."
    "Remove the app only. Your settings, logins and extensions stay."
    "Remove the app plus its settings, logs, cache and extensions."
    "Show what is installed on this system."
    "Quit without changing anything."
  )
  printf '\n  %sWhat would you like to do?%s %s(arrows or 1-5, Enter to select, q to quit)%s\n\n' "$B" "$R" "$D" "$R"
  choose
  case "$CHOICE" in
    0) CMD="install" ;;
    1) CMD="uninstall" ;;
    2) CMD="purge" ;;
    3) CMD="status" ;;
    *) printf '\n'; exit 0 ;;
  esac
}

# ======================================================================
# INSTALL
# ======================================================================
search_tarballs() {
  local pattern="$1" dirs=() d
  for d in "$HOME/Downloads" "$HOME/Desktop" "$PWD"; do
    if [ -d "$d" ]; then dirs+=("$d"); fi
  done
  if [ ${#dirs[@]} -eq 0 ]; then return 0; fi
  find "${dirs[@]}" -maxdepth 1 -type f \( -iname "$pattern.tar.gz" -o -iname "$pattern.tgz" \) \
    -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2- || true
}

find_tarball() {
  local f
  f=$(search_tarballs '*antigravity*ide*')
  if [ -z "$f" ]; then f=$(search_tarballs '*antigravity*'); fi
  printf '%s' "$f" > "$WORK/found"
  sleep 0.6
}

find_partial() {
  local dirs=() d
  for d in "$HOME/Downloads" "$HOME/Desktop" "$PWD"; do
    if [ -d "$d" ]; then dirs+=("$d"); fi
  done
  if [ ${#dirs[@]} -eq 0 ]; then return 0; fi
  find "${dirs[@]}" -maxdepth 1 -type f \( -iname '*antigravity*.crdownload' -o -iname '*antigravity*.part' -o -iname '*antigravity*.download' \) 2>/dev/null | head -n1 || true
}

missing_file() {
  local arch="x64"
  case "$(uname -m)" in aarch64|arm64) arch="ARM64" ;; esac
  printf '\n  %s✘ Antigravity IDE tarball not found.%s\n' "$RED" "$R"
  printf '  %sStopping here. Download it first, then run this script again.%s\n\n' "$YEL" "$R"
  printf '  %sHow to download%s\n' "$B" "$R"
  printf '   1. Open  %s%s%s\n' "$CYN" "$DOWNLOAD_PAGE" "$R"
  printf '      (or run: %sxdg-open %s%s)\n' "$B" "$DOWNLOAD_PAGE" "$R"
  printf '   2. Pick %sAntigravity IDE%s for Linux (%s, matches your CPU)\n' "$B" "$R" "$arch"
  printf '   3. Save the .tar.gz into %s~/Downloads%s\n' "$B" "$R"
  printf '   4. Run again:  %sbash antigravity-setup.sh install%s\n\n' "$B" "$R"
  printf '  %sSaved it somewhere else?%s\n' "$B" "$R"
  printf '     %sbash antigravity-setup.sh install --tarball /path/to/file.tar.gz%s\n\n' "$B" "$R"
  exit 1
}

verify_archive() {
  gzip -t "$ARCHIVE" || { echo "Archive is incomplete or corrupt. Delete it and download it again."; return 1; }
  tar -tzf "$ARCHIVE" | sed 's#^\./##' | sed '/^$/d' >"$WORK/list" || { echo "Cannot read the archive. Download it again."; return 1; }
  local top
  top=$(head -n1 "$WORK/list" | cut -d/ -f1)
  [ -n "$top" ] || { echo "Archive is empty."; return 1; }
  grep -Fxq -- "$top/antigravity-ide" "$WORK/list" || {
    echo "This does not look like the Antigravity IDE tarball (launcher not found)."
    echo "Make sure you downloaded 'Antigravity IDE', not the 2.0 desktop app or CLI."
    return 1
  }
  printf '%s' "$top" >"$WORK/top"
}

install_deps() {
  sudo apt-get update -qq || echo "apt update failed, continuing"
  local pkgs=(tar gzip python3 desktop-file-utils ca-certificates) spec o pick
  local libs=("libnss3" "libgbm1" "libxss1" "libxkbcommon0" "libasound2t64|libasound2" "libgtk-3-0t64|libgtk-3-0" "libatk-bridge2.0-0t64|libatk-bridge2.0-0")
  for spec in "${libs[@]}"; do
    pick=""
    IFS='|' read -ra opts <<<"$spec"
    for o in "${opts[@]}"; do
      if apt-cache show "$o" >/dev/null 2>&1; then pick="$o"; break; fi
    done
    if [ -n "$pick" ]; then pkgs+=("$pick"); fi
  done
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkgs[@]}"
}

extract_archive() {
  mkdir -p "$WORK/extract"
  tar -xzf "$ARCHIVE" -C "$WORK/extract"
}

detect_version() {
  local top src v=""
  top=$(cat "$WORK/top"); src="$WORK/extract/$top"
  if [ -f "$src/resources/app/package.json" ]; then
    v=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("version",""))' "$src/resources/app/package.json" 2>/dev/null || true)
  fi
  printf '%s' "${v:-unknown}"
}

copy_files() {
  local top src
  top=$(cat "$WORK/top"); src="$WORK/extract/$top"
  [ -x "$src/antigravity-ide" ] || { echo "launcher missing after extract"; return 1; }
  sudo rm -rf "${INSTALL_ROOT}.new"
  sudo mkdir -p "${INSTALL_ROOT}.new/$INSTALL_DIR"
  sudo cp -a "$src/." "${INSTALL_ROOT}.new/$INSTALL_DIR/"
  printf '%s\n' "$VERSION" | sudo tee "${INSTALL_ROOT}.new/.version" >/dev/null
  if [ -d "$INSTALL_ROOT" ]; then
    sudo rm -rf "${INSTALL_ROOT}.previous"
    sudo mv "$INSTALL_ROOT" "${INSTALL_ROOT}.previous"
  fi
  sudo mv "${INSTALL_ROOT}.new" "$INSTALL_ROOT"
}

fix_sandbox() {
  local sb="$INSTALL_ROOT/$INSTALL_DIR/chrome-sandbox"
  if [ -f "$sb" ]; then
    sudo chown root:root "$sb"
    sudo chmod 4755 "$sb"
  fi
}

link_command() {
  if [ -e "$BIN_LINK" ] && [ ! -L "$BIN_LINK" ]; then
    echo "$BIN_LINK exists and is not a symlink. Move it first."; return 1
  fi
  sudo ln -sfn "$INSTALL_ROOT/$INSTALL_DIR/antigravity-ide" "$BIN_LINK"
}

register_launcher() {
  local icon_src="$INSTALL_ROOT/$INSTALL_DIR/resources/app/resources/linux/code.png"
  if [ -f "$icon_src" ]; then sudo install -Dm644 "$icon_src" "$ICON_FILE"; fi
  sudo tee "$DESKTOP_FILE" >/dev/null <<EOF
[Desktop Entry]
Name=Antigravity IDE
Comment=Google Antigravity IDE
Exec=$BIN_LINK %U
Icon=antigravity-ide
Terminal=false
Type=Application
Categories=Development;IDE;
MimeType=x-scheme-handler/antigravity-ide;application/x-antigravity-workspace;
StartupNotify=true
StartupWMClass=antigravity-ide
EOF
  if command -v update-desktop-database >/dev/null 2>&1; then
    sudo update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    sudo gtk-update-icon-cache -q /usr/share/icons/hicolor >/dev/null 2>&1 || true
  fi
}

verify_install() {
  local target sb
  target=$(readlink -f "$BIN_LINK")
  [ -x "$target" ] || { echo "launcher not executable: $target"; return 1; }
  sb="$INSTALL_ROOT/$INSTALL_DIR/chrome-sandbox"
  if [ -e "$sb" ]; then
    [ "$(stat -c '%U:%G:%a' "$sb")" = "root:root:4755" ] || { echo "sandbox permissions wrong"; return 1; }
  fi
  if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$DESKTOP_FILE" || true
  fi
}

do_install() {
  STEP=0; TOTAL=3
  local start=$SECONDS found partial old

  phase "Checking for the downloaded file"
  require_user
  command -v apt-get >/dev/null 2>&1 || die "This installer supports apt-based systems only (Kali, Debian, Ubuntu)."
  case "$(uname -m)" in
    x86_64|amd64|aarch64|arm64) ;;
    *) die "Unsupported architecture: $(uname -m)" ;;
  esac
  if [ -n "$TARBALL" ]; then
    if [ ! -f "$TARBALL" ]; then warn "File not found: $TARBALL"; missing_file; fi
    ARCHIVE=$(readlink -f "$TARBALL")
  else
    run_step "Searching ~/Downloads, ~/Desktop and the current folder" find_tarball
    found=$(cat "$WORK/found")
    if [ -z "$found" ]; then
      partial=$(find_partial)
      if [ -n "$partial" ]; then
        printf '\n  %s✘ A download is still in progress or was interrupted:%s\n    %s\n' "$RED" "$R" "$partial"
        printf '  %sWait for it to finish, then run this script again.%s\n\n' "$YEL" "$R"
        exit 1
      fi
      missing_file
    fi
    ARCHIVE=$(readlink -f "$found")
  fi
  ok "Found: $ARCHIVE ($(human "$(stat -c%s "$ARCHIVE")") MB)"
  run_step "Checking archive integrity and layout" verify_archive

  phase "Installing to $INSTALL_ROOT"
  if [ -f "$INSTALL_ROOT/.version" ]; then
    old=$(cat "$INSTALL_ROOT/.version" 2>/dev/null || echo unknown)
    info "Existing install (version $old) will be replaced. Backup: $INSTALL_ROOT.previous"
  fi
  ensure_sudo
  run_step "Installing runtime libraries" install_deps
  run_step "Extracting files" extract_archive
  VERSION=$(detect_version)
  run_step "Copying files into place (version $VERSION)" copy_files
  run_step "Setting up the Chromium sandbox helper (root, 4755)" fix_sandbox

  phase "Setting up command, launcher and verifying"
  run_step "Creating the antigravity-ide command" link_command
  run_step "Registering the app-menu launcher and icon" register_launcher
  run_step "Checking launcher, sandbox and desktop entry" verify_install

  local hr
  hr=$(printf '═%.0s' $(seq 1 58))
  row() { printf '  %s║%s %-56s %s║%s\n' "$GRN" "$R" "$1" "$GRN" "$R"; }
  printf '\n  %s╔%s╗%s\n' "$GRN" "$hr" "$R"
  row "Installation complete"
  printf '  %s╠%s╣%s\n' "$GRN" "$hr" "$R"
  row "Version   $VERSION"
  row "Location  $INSTALL_ROOT/$INSTALL_DIR"
  row "Command   antigravity-ide"
  row "Launcher  Applications menu > Antigravity IDE"
  row "Time      $((SECONDS - start))s"
  printf '  %s╚%s╝%s\n' "$GRN" "$hr" "$R"

  printf '\n  %sTips%s\n' "$B" "$R"
  printf '  %s•%s Black window or crash: run %santigravity-ide --disable-gpu%s from a terminal\n' "$CYN" "$R" "$B" "$R"
  printf '  %s•%s Update: download the new tarball and run install again\n' "$CYN" "$R"
  printf '  %s•%s Previous version is kept at %s.previous\n\n' "$CYN" "$R" "$INSTALL_ROOT"

  if [ "$YES" = 0 ] && [ -t 0 ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    local ans
    if [ "$TTY" = 1 ]; then printf '\e[?25h'; fi
    read -r -p "  Launch $APP_NAME now? [Y/n] " ans || ans="n"
    case "${ans:-Y}" in
      [Yy]*) nohup "$BIN_LINK" >/dev/null 2>&1 & disown; ok "Launching..." ;;
    esac
  fi
}

# ======================================================================
# UNINSTALL
# ======================================================================
SYS_PATHS=(
  "$INSTALL_ROOT" "${INSTALL_ROOT}.previous" "${INSTALL_ROOT}.new"
  "$BIN_LINK" "$DESKTOP_FILE" "/usr/share/applications/antigravity-ide-x11.desktop" "$ICON_FILE"
  "/etc/apparmor.d/antigravity-ide" "/etc/apparmor.d/local/antigravity-ide"
)
DATA_PATHS=(
  "$HOME/.config/Antigravity IDE"
  "$HOME/.antigravity-ide"
  "$HOME/.gemini/antigravity-ide"
  "$HOME/.cache/Antigravity IDE"
  "$HOME/.local/share/Antigravity IDE"
)
PLAN_SYS=(); PLAN_USER=(); PLAN_DATA=(); DEB_IDE=0

collect_plan() {
  local p
  PLAN_SYS=(); PLAN_USER=(); PLAN_DATA=(); DEB_IDE=0
  for p in "${SYS_PATHS[@]}"; do
    if exists "$p"; then PLAN_SYS+=("$p"); fi
  done
  for p in "$HOME/Applications/antigravity-ide" "$HOME/.local/bin/antigravity-ide" "$HOME"/.local/share/applications/antigravity-ide*.desktop; do
    if exists "$p"; then PLAN_USER+=("$p"); fi
  done
  for p in "${DATA_PATHS[@]}"; do
    if exists "$p"; then PLAN_DATA+=("$p"); fi
  done
  if dpkg -s antigravity-ide >/dev/null 2>&1; then DEB_IDE=1; fi
}

print_list() {
  local title="$1" p s; shift
  printf '  %s%s%s\n' "$B" "$title" "$R"
  for p in "$@"; do
    s=$(psize "$p")
    printf '    %s-%s %s %s(%s)%s\n' "$CYN" "$R" "$p" "$D" "${s:-?}" "$R"
  done
}

stop_procs() {
  if pgrep -x antigravity-ide >/dev/null 2>&1; then
    pkill -x antigravity-ide || true
    sleep 1.5
    pkill -9 -x antigravity-ide 2>/dev/null || true
  fi
}

purge_deb() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y antigravity-ide
  sudo apt-get autoremove -y
}

remove_system() {
  local p
  if [ -f /etc/apparmor.d/antigravity-ide ] && command -v apparmor_parser >/dev/null 2>&1; then
    sudo apparmor_parser -R /etc/apparmor.d/antigravity-ide 2>/dev/null || true
  fi
  for p in "${PLAN_SYS[@]}"; do sudo rm -rf -- "$p"; done
}

remove_user_files() {
  local p
  for p in "${PLAN_USER[@]}"; do rm -rf -- "$p"; done
}

remove_user_data() {
  local p
  for p in "${PLAN_DATA[@]}"; do rm -rf -- "$p"; done
}

refresh_desktop() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    sudo update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    sudo gtk-update-icon-cache -q /usr/share/icons/hicolor >/dev/null 2>&1 || true
  fi
}

leftover_scan() {
  local roots=("$HOME/.config" "$HOME/.cache" "$HOME/.local" "$HOME/Applications" "$HOME/.gemini" "$HOME/.antigravity-ide" \
               /opt /usr/local /usr/share/applications /usr/share/icons /etc/apparmor.d) r
  local existing=()
  for r in "${roots[@]}"; do
    if [ -e "$r" ]; then existing+=("$r"); fi
  done
  find "${existing[@]}" -maxdepth 4 \( -iname '*antigravity*ide*' \) -not -path '*/google-chrome/*' 2>/dev/null || true
}

do_uninstall() {
  local full="$1" start=$SECONDS left
  STEP=0; TOTAL=3
  require_user

  phase "Scanning for $APP_NAME"
  collect_plan
  if [ ${#PLAN_SYS[@]} -eq 0 ] && [ ${#PLAN_USER[@]} -eq 0 ] && [ $DEB_IDE -eq 0 ] && { [ "$full" = 0 ] || [ ${#PLAN_DATA[@]} -eq 0 ]; }; then
    ok "Nothing to remove. $APP_NAME is not installed."
    if [ "$full" = 0 ] && [ ${#PLAN_DATA[@]} -gt 0 ]; then info "Settings found. Choose 'Full uninstall' to remove them."; fi
    return 0
  fi
  if [ ${#PLAN_SYS[@]} -gt 0 ]; then print_list "System install" "${PLAN_SYS[@]}"; fi
  if [ ${#PLAN_USER[@]} -gt 0 ]; then print_list "Manual install and launchers" "${PLAN_USER[@]}"; fi
  if [ $DEB_IDE -eq 1 ]; then printf '  %sPackage%s\n    %s-%s antigravity-ide (apt purge)\n' "$B" "$R" "$CYN" "$R"; fi
  if [ "$full" = 1 ]; then
    if [ ${#PLAN_DATA[@]} -gt 0 ]; then print_list "Settings, logs, cache and extensions (will be deleted)" "${PLAN_DATA[@]}"; fi
  elif [ ${#PLAN_DATA[@]} -gt 0 ]; then
    printf '  %sKept (not touched)%s\n' "$B" "$R"
    for p in "${PLAN_DATA[@]}"; do printf '    %s-%s %s\n' "$D" "$R" "$p"; done
  fi
  printf '\n'
  if ! confirm "Remove the items above?"; then info "Cancelled. Nothing was changed."; return 0; fi

  phase "Removing"
  if [ ${#PLAN_SYS[@]} -gt 0 ] || [ $DEB_IDE -eq 1 ]; then ensure_sudo; fi
  run_step "Closing running Antigravity IDE windows" stop_procs
  if [ $DEB_IDE -eq 1 ]; then run_step "Purging the apt package" purge_deb; fi
  if [ ${#PLAN_SYS[@]} -gt 0 ]; then run_step "Removing system files" remove_system; fi
  if [ ${#PLAN_USER[@]} -gt 0 ]; then run_step "Removing manual install and launchers" remove_user_files; fi
  if [ "$full" = 1 ] && [ ${#PLAN_DATA[@]} -gt 0 ]; then run_step "Deleting settings, logs and extensions" remove_user_data; fi

  phase "Verifying"
  if [ -n "$SUDO_PID" ]; then run_step "Refreshing the app menu" refresh_desktop; fi
  left=$(leftover_scan)
  if [ "$full" = 0 ] && [ ${#PLAN_DATA[@]} -gt 0 ]; then
    ok "App removed. Settings were kept."
  elif [ -z "$left" ]; then
    ok "Clean. Nothing Antigravity IDE related is left."
  else
    warn "Some items are still present:"
    printf '%s\n' "$left" | sed 's/^/      /'
  fi
  if dpkg -s antigravity >/dev/null 2>&1; then
    warn "The 'antigravity' apt package (legacy IDE or 2.0 desktop) is installed and was not touched."
    printf '      Remove it with: %ssudo apt purge antigravity%s\n' "$B" "$R"
  fi
  printf '\n  %sDone in %ss.%s' "$GRN" "$((SECONDS - start))" "$R"
  printf '\n  %sIf you signed in with Google, revoke access at myaccount.google.com > Security > Third-party apps and services.%s\n\n' "$D" "$R"
}

# ======================================================================
# STATUS
# ======================================================================
do_status() {
  STEP=0; TOTAL=1
  local v f perms p s any=0
  phase "Antigravity IDE status"
  if [ -d "$INSTALL_ROOT/$INSTALL_DIR" ]; then
    v=$(cat "$INSTALL_ROOT/.version" 2>/dev/null || echo unknown)
    ok "Installed: version $v at $INSTALL_ROOT/$INSTALL_DIR"
  else
    warn "Not installed in $INSTALL_ROOT"
  fi
  if [ -L "$BIN_LINK" ]; then ok "Command: $BIN_LINK -> $(readlink -f "$BIN_LINK")"; else warn "Command $BIN_LINK is missing"; fi
  if [ -f "$DESKTOP_FILE" ]; then ok "App-menu launcher present"; else warn "App-menu launcher missing"; fi
  if [ -e "$INSTALL_ROOT/$INSTALL_DIR/chrome-sandbox" ]; then
    perms=$(stat -c '%U:%G:%a' "$INSTALL_ROOT/$INSTALL_DIR/chrome-sandbox")
    if [ "$perms" = "root:root:4755" ]; then ok "Sandbox helper permissions OK ($perms)"; else warn "Sandbox helper permissions are $perms (expected root:root:4755)"; fi
  fi
  if [ -d "$HOME/Applications/antigravity-ide" ]; then warn "Old manual install found: ~/Applications/antigravity-ide"; fi
  if dpkg -s antigravity-ide >/dev/null 2>&1; then warn "apt package 'antigravity-ide' is installed"; fi
  if dpkg -s antigravity >/dev/null 2>&1; then info "apt package 'antigravity' is installed (legacy IDE or 2.0 desktop)"; fi
  if pgrep -x antigravity-ide >/dev/null 2>&1; then info "Antigravity IDE is running right now"; fi
  for p in "${DATA_PATHS[@]}"; do
    if exists "$p"; then
      s=$(psize "$p")
      if [ $any -eq 0 ]; then info "User data present:"; any=1; fi
      printf '      %s (%s)\n' "$p" "${s:-?}"
    fi
  done
  f=$(search_tarballs '*antigravity*ide*')
  if [ -n "$f" ]; then info "Downloaded tarball found: $f"; else info "No downloaded tarball found in ~/Downloads, ~/Desktop or here"; fi
  printf '\n'
}

# ======================================================================
# MAIN
# ======================================================================
banner

if [ -z "$CMD" ]; then
  if [ -t 0 ] && [ "$TTY" = 1 ]; then
    interactive_menu
  else
    printf '\n'; usage; exit 1
  fi
fi

case "$CMD" in
  install)   do_install ;;
  uninstall) do_uninstall 0 ;;
  purge)     do_uninstall 1 ;;
  status)    do_status ;;
esac
