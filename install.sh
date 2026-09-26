#!/usr/bin/env bash
# Installer. Run as root:  sudo bash ./install.sh
#
# Creates the `librarian` user, installs the commands under /usr/local, writes
# the systemd units, and prompts once for config and secrets (kept root-owned
# in /etc/librarian). Idempotent: re-running deploys the current code and skips
# what exists. Lays out the vault with librarian-vault-init if it is empty.
# Deploy after a change = git pull, sudo bash ./install.sh; see INSTALL.md.
set -euo pipefail

SRC=$(cd "$(dirname "$0")" && pwd)
CONF=/etc/librarian            # root-owned: nothing running as librarian can change what root reads
LIB=/usr/local/lib/librarian
STATE=/var/lib/librarian
U=${SUDO_USER:?run with sudo from your own account}
as_lib() { sudo -u librarian -H "$@"; }

echo "== packages and user =="
DEBIAN_FRONTEND=noninteractive apt-get install -y git gh python3 curl >/dev/null
id librarian >/dev/null 2>&1 || useradd --system --create-home --shell /bin/bash librarian

echo "== config =="
install -d -o root -g librarian -m 750 "$CONF"
install -d -o librarian -g librarian -m 755 "$STATE"
for d in "$STATE/runs" /var/log/librarian; do            # run artifacts hold note text
  [ -L "$d" ] && { echo "$d is a symlink; refusing"; exit 1; }
  install -d -o librarian -g librarian -m 750 "$d"; chmod 750 "$d"
done
if [ ! -s "$CONF/env" ]; then
  read -rp "Vault directory (absolute; not under /home, /var or /tmp, which the model is denied): " VAULT_DIR
  read -rp "Work realm folder name (work/<this>/, e.g. acme): " WORK_CO
  read -rp "Your name for git commits [$(getent passwd "$U" | cut -d: -f5 | cut -d, -f1)]: " YOU_NAME
  YOU_NAME=${YOU_NAME:-$(getent passwd "$U" | cut -d: -f5 | cut -d, -f1)}
  read -rp "Your email for git commits: " YOU_EMAIL
  read -rp "GitHub repo slug (owner/name), empty to skip GitHub for now: " GITHUB_REPO
  read -rp "healthchecks.io ping URL for the librarian (optional): " HC_URL
  read -rp "Stop file: the nightly refuses to run while this path exists (optional, e.g. a backup tripwire): " STOP_FLAG
  install -o root -g librarian -m 640 /dev/null "$CONF/env"
  cat > "$CONF/env" <<EOT
VAULT_DIR='$VAULT_DIR'
WORK_CO='$WORK_CO'
YOU_NAME='$YOU_NAME'
YOU_EMAIL='$YOU_EMAIL'
GITHUB_REPO='$GITHUB_REPO'
HC_URL='$HC_URL'
STOP_FLAG='$STOP_FLAG'
EOT
fi
chown root:librarian "$CONF/env"; chmod 640 "$CONF/env"
# Read the config as data (never source a file as root): KEY='value' lines, known keys only.
cfg() { sed -n "s/^$1='\([^']*\)'\$/\1/p" "$CONF/env" | head -1; }
VAULT_DIR=$(cfg VAULT_DIR); WORK_CO=$(cfg WORK_CO); GITHUB_REPO=$(cfg GITHUB_REPO)
[ -n "$VAULT_DIR" ] && [ -n "$WORK_CO" ] || { echo "$CONF/env is incomplete"; exit 1; }
VAULT=$VAULT_DIR
case $VAULT in
  /home/*|/var/*|/tmp/*|/etc/*|/root/*|/run/*|/proc/*) echo "the vault cannot live under $(dirname "$VAULT"): the model's static deny list covers it (lib/settings.sh)"; exit 1;;
  /*) ;;
  *) echo "VAULT_DIR must be absolute"; exit 1;;
esac
WORK=$(dirname "$VAULT")/librarian    # the model's worktrees live here, next to the vault, never inside it
[ -d "$VAULT" ] || install -d -o librarian -g librarian -m 2750 "$VAULT"
install -d -o librarian -g librarian -m 750 "$WORK"
if [ -n "$GITHUB_REPO" ] && [ ! -s "$CONF/github-token" ]; then
  read -rsp "Fine-grained GitHub token for $GITHUB_REPO (not echoed): " TOKEN; echo
  install -o librarian -g librarian -m 600 /dev/null "$CONF/github-token"
  printf '%s' "$TOKEN" > "$CONF/github-token"
  install -o librarian -g librarian -m 600 /dev/null "$CONF/git-credentials"
  printf 'https://x-access-token:%s@github.com\n' "$TOKEN" > "$CONF/git-credentials"
  unset TOKEN
fi
if [ ! -e "$CONF/work-token" ]; then
  read -rsp "Team/Enterprise token for the work realm from 'claude setup-token' (Enter to skip; work runs on the personal login): " TOKEN; echo
  install -o librarian -g librarian -m 600 /dev/null "$CONF/work-token"   # exists-but-empty = asked, skipped
  [ -n "$TOKEN" ] && printf '%s' "$TOKEN" > "$CONF/work-token"
  unset TOKEN
fi

echo "== library, commands, prompts =="
install -d -m 755 "$LIB" "$LIB/prompts" "$LIB/vault"
install -m 755 "$SRC/bin/dailynote.py" "$LIB/dailynote.py"
install -m 644 "$SRC/lib/settings.sh" "$LIB/settings.sh"
install -m 755 "$SRC/lib/guard" "$LIB/guard"
install -m 644 "$SRC/prompts/file.md" "$SRC/prompts/tidy.md" "$LIB/prompts/"
install -m 644 "$SRC"/vault/* "$LIB/vault/"
install -m 755 "$SRC/bin/librarian-nightly" "$SRC/bin/librarian-newday" "$SRC/bin/librarian-boundary-test" "$SRC/bin/librarian-vault-init" /usr/local/bin/

echo "== Claude Code for the librarian user =="
if [ ! -x /home/librarian/.local/bin/claude ]; then
  as_lib bash -c 'curl -fsSL https://claude.ai/install.sh | bash' >/dev/null
fi
# Pin the runs to the version installed now (the launcher symlink would follow
# auto-updates, silently invalidating the last boundary-test PASS). Re-running
# the installer re-pins; run librarian-boundary-test afterwards.
CLAUDE_PIN=$(readlink -f /home/librarian/.local/bin/claude)
sed -i '/^CLAUDE_BIN=/d' "$CONF/env"
printf "CLAUDE_BIN='%s'\n" "$CLAUDE_PIN" >> "$CONF/env"
echo "claude pinned: $CLAUDE_PIN ($(as_lib "$CLAUDE_PIN" --version 2>/dev/null || echo '?'))"

echo "== vault layout =="
as_lib /usr/local/bin/librarian-vault-init          # realm folders, rule files, template, git init; skips what exists
as_lib /usr/local/bin/librarian-newday "$(date +%F)"

echo "== git remote =="
as_lib git -C "$VAULT" config credential.helper "store --file $CONF/git-credentials"
if [ -n "$GITHUB_REPO" ]; then
  as_lib git -C "$VAULT" remote get-url origin >/dev/null 2>&1 || as_lib git -C "$VAULT" remote add origin "https://github.com/$GITHUB_REPO.git"
  as_lib git -C "$VAULT" push -q -u origin main && echo "pushed to $GITHUB_REPO"
fi

echo "== .gitignore =="
install -o librarian -g librarian -m 644 "$SRC/vault/gitignore" "$VAULT/.gitignore"   # every run, so existing repos pick up new entries
as_lib git -C "$VAULT" add -- .gitignore
as_lib git -C "$VAULT" diff --cached --quiet -- .gitignore || as_lib git -C "$VAULT" commit -qm "gitignore: librarian entries"

echo "== lessons files =="
for d in personal "work/$WORK_CO"; do
  [ -f "$VAULT/$d/lessons.md" ] || install -o librarian -g librarian -m 644 "$SRC/vault/lessons.md" "$VAULT/$d/lessons.md"
done
as_lib git -C "$VAULT" add -A -- personal/lessons.md "work/$WORK_CO/lessons.md" 2>/dev/null || true
as_lib git -C "$VAULT" diff --cached --quiet 2>/dev/null || as_lib git -C "$VAULT" commit -qm "lessons.md per realm"

echo "== syncthing ignore list =="
if [ -f "$VAULT/.stignore" ]; then      # only if the vault is a Syncthing folder
  # git internals; Claude Code config that could carry hooks, MCP servers or skills
  for pat in '/.git' '/.claude' '/.mcp.json' '/CLAUDE.local.md'; do
    grep -qxF "$pat" "$VAULT/.stignore" || echo "$pat" | as_lib tee -a "$VAULT/.stignore" >/dev/null
  done
  # keep the vault clean: the wrapper and the boundary test refuse a dirty tree
  as_lib git -C "$VAULT" diff --quiet -- .stignore 2>/dev/null || as_lib git -C "$VAULT" commit -qm "stignore: librarian entries" -- .stignore
fi

echo "== systemd =="
cat > /etc/systemd/system/librarian-nightly.service <<EOT
[Unit]
Description=Librarian nightly filing (yesterday's daily note)
After=network-online.target

[Service]
Type=oneshot
User=librarian
WorkingDirectory=$VAULT
Environment=DISABLE_AUTOUPDATER=1
ExecStart=/usr/local/bin/librarian-nightly
Nice=10
EOT
cat > /etc/systemd/system/librarian-nightly.timer <<'EOT'
[Unit]
Description=Librarian nightly at 03:00

[Timer]
OnCalendar=*-*-* 03:00:00
RandomizedDelaySec=5m
Persistent=true

[Install]
WantedBy=timers.target
EOT
cat > /etc/systemd/system/librarian-newday.service <<'EOT'
[Unit]
Description=Create today's daily note from the template

[Service]
Type=oneshot
User=librarian
ExecStart=/usr/local/bin/librarian-newday
EOT
cat > /etc/systemd/system/librarian-newday.timer <<'EOT'
[Unit]
Description=Daily note creation at 00:05

[Timer]
OnCalendar=*-*-* 00:05:00
Persistent=true

[Install]
WantedBy=timers.target
EOT
systemctl daemon-reload
systemctl enable --now librarian-newday.timer
# The nightly is never armed by the installer: arming it is a deliberate act
# after the boundary test passes on the deployed code.
if systemctl is-enabled --quiet librarian-nightly.timer 2>/dev/null; then
  echo "librarian-nightly.timer is enabled; the deployed code just changed, so disarming it. Re-arm after librarian-boundary-test passes:"
  echo "    sudo systemctl enable --now librarian-nightly.timer"
  systemctl disable --now librarian-nightly.timer
fi
systemctl list-timers 'librarian-*' --no-pager

cat <<EOT

Done. Vault: $VAULT. Remaining, once (INSTALL.md has the details):
  1. Log the librarian user into Claude Code:  sudo -u librarian -H bash -c 'cd && claude'  then /exit
  2. Prove the write boundary (expects PASS):  sudo -u librarian -H librarian-boundary-test
  3. Arm the nightly after step 2 passes:      sudo systemctl enable --now librarian-nightly.timer
EOT
