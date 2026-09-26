# Shared by librarian-nightly and librarian-boundary-test. Sourced, never run.
# How the model is confined lives here and in lib/guard; docs/boundaries.md
# explains it. Expects: CLAUDE (binary), LIB, cwd = vault root, HOME = librarian's.

GUARD=${GUARD:-${LIB:-/usr/local/lib/librarian}/guard}

# The five tools the model has. --tools removes every other tool (no shell, no
# web, no MCP, no skills); --allowedTools lets these five run without a prompt.
CLAUDE_TOOLS="Read,Edit,Write,Glob,Grep"

# Belt only: the pinned binary path in $CONF/env is what fixes the version.
export DISABLE_AUTOUPDATER=1

# make_settings realm_dir out_file        (realm_dir: personal | work/<co>)
# Per-run Claude Code settings. The guard decides every vault path; the deny
# list below is a short static backstop for system paths that never change
# (so the vault and its worktree must not live under them; install.sh checks).
make_settings() {
  python3 - "$2" "$GUARD" <<'PY'
import json, sys
out, guard = sys.argv[1:3]
deny = ["Read(.git/**)", "Edit(.git/**)",
        "Read(//home/**)", "Read(//root/**)", "Read(//etc/**)", "Read(//proc/**)", "Read(//run/**)", "Read(//var/**)",
        "Edit(//home/**)", "Edit(//root/**)", "Edit(//etc/**)", "Edit(//proc/**)", "Edit(//run/**)", "Edit(//var/**)", "Edit(//tmp/**)"]
settings = {
    "permissions": {"deny": deny, "blockReadsOutsideWorkingDirectories": True},
    "hooks": {"PreToolUse": [{"matcher": "Read|Edit|Write|Glob|Grep",
                              "hooks": [{"type": "command", "command": guard, "timeout": 10}]}]},
    "cleanupPeriodDays": 7,   # not confinement: how long the librarian's transcripts stay on disk
}
json.dump(settings, open(out, "w"), indent=1)
PY
}

# claude_confined prompt_file settings_file out_prefix max_turns realm_dir
# Runs one confined `claude -p`. Writes: <out_prefix>.json (full result),
# <out_prefix>.md (the model's final text), <out_prefix>.denials (one line per
# denied call: "Tool path [rule]" from Claude Code or "Tool path [guard]"),
# <out_prefix>.writes (every path the guard let the model write, vault-relative),
# <out_prefix>.err. Returns claude's exit status.
claude_confined() {
  local prompt=$1 settings=$2 out=$3 turns=${4:-80} realm=$5 rc=0
  : > "$out.writes"; : > "$out.guard"
  # env -i: nothing from the wrapper's environment (GH_TOKEN, HC_URL, ...) reaches the model.
  # --restricted: file tools fenced to the vault; user/project settings files ignored.
  # --strict-mcp-config: no MCP servers from a synced .mcp.json.
  # --permission-prompts none: anything that would ask a human is denied.
  # Prompt on stdin: not visible in the process list.
  # LIBRARIAN_OAUTH_TOKEN (set by the caller for one run) becomes CLAUDE_CODE_OAUTH_TOKEN, which
  # Claude Code prefers over the stored login: the work realm runs on a work account this way.
  env -i HOME="$HOME" PATH="$PATH" USER="${USER:-librarian}" LANG="${LANG:-C.UTF-8}" TERM=dumb \
      DISABLE_AUTOUPDATER=1 ${LIBRARIAN_OAUTH_TOKEN:+CLAUDE_CODE_OAUTH_TOKEN="$LIBRARIAN_OAUTH_TOKEN"} \
      LIBRARIAN_VAULT="$PWD" LIBRARIAN_REALM_DIR="$realm" LIBRARIAN_WRITES_LOG="$out.writes" LIBRARIAN_GUARD_LOG="$out.guard" \
    "$CLAUDE" -p --settings "$settings" \
      --restricted --strict-mcp-config --permission-prompts none \
      --tools "$CLAUDE_TOOLS" --allowedTools "$CLAUDE_TOOLS" \
      --max-turns "$turns" --output-format json < "$prompt" > "$out.json" 2>"$out.err" || rc=$?
  python3 - "$out" <<'PY' || true
import json, os, sys
out = sys.argv[1]
try:
    r = json.load(open(out + ".json"))
except Exception:
    open(out + ".md", "w").write(""); open(out + ".denials", "w").write(""); sys.exit(0)
open(out + ".md", "w").write(r.get("result") or "")
# Claude Code's list includes calls the guard denied; a call the guard never saw
# was stopped earlier by a deny rule (or the fence).
guard = set(l.rstrip("\n") for l in open(out + ".guard")) if os.path.exists(out + ".guard") else set()
lines = set()
for d in r.get("permission_denials") or []:
    i = d.get("tool_input") or {}
    what = i.get("file_path") or i.get("path") or i.get("command") or i.get("pattern") or ""
    call = f"{d.get('tool_name','?')} {what}"
    lines.add(call + (" [guard]" if call in guard else " [rule]"))
for call in guard:
    lines.add(call + " [guard]")
open(out + ".denials", "w").write("".join(l + "\n" for l in sorted(lines)))
PY
  return $rc
}

# claude_login_hint stderr_file -> extra text for a failure message
claude_login_hint() {
  grep -qiE "login expired|not logged in|please run /login|authentication" "$1" 2>/dev/null \
    && echo " (librarian is not logged in: sudo -u librarian -H bash -c 'cd && /home/librarian/.local/bin/claude', then /exit)"
  true
}
