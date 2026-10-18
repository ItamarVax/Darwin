#!/usr/bin/env bash
# Shell safety blocklist. Blocks only catastrophic, hard-to-reverse
# commands; ordinary destructive-but-scoped commands (rm -rf build/,
# git reset --hard, --force-with-lease) are left to the host's own
# permission system.
source "$(dirname "$0")/lib.sh"

read_stdin
if [[ "$(detect_platform)" == "claude" ]]; then
  command=$(json_field "tool_input.command")
else
  command=$(json_field "command")
fi

if [[ -z "$command" ]]; then
  exit 0
fi

block() {
  local reason="$1"
  if [[ "$(detect_platform)" == "cursor" ]]; then
    printf '{"permission":"deny","user_message":%s,"agent_message":%s}\n' \
      "$(json_string "Blocked by Darwin safety hook: $reason")" \
      "$(json_string "Blocked by Darwin safety hook ($reason). Do not retry; ask the user to run it themselves if it is really intended.")"
  fi
  echo "BLOCKED by Darwin safety hook ($reason): $command" >&2
  exit 2
}

# Targets that make a recursive force-delete catastrophic.
DANGEROUS_RM_TARGET='^(/|/\*|~|~/|~/\*|\$HOME|\$HOME/|\$HOME/\*|\$\{HOME\}|\$\{HOME\}/|\.|\./|\./\*|\.\.|\.\./|\*)$'

# Check one simple command (no ; && || |) for a dangerous rm.
check_rm() {
  local -a words
  read -r -a words <<<"$1"
  local i=0
  [[ "${words[0]:-}" == "sudo" ]] && i=1
  [[ "${words[$i]:-}" == "rm" ]] || return 0
  local recursive=0 force=0 w
  local -a targets=()
  for w in "${words[@]:$((i + 1))}"; do
    case "$w" in
      --recursive) recursive=1 ;;
      --force) force=1 ;;
      --*) ;;
      -*)
        [[ "$w" == *[rR]* ]] && recursive=1
        [[ "$w" == *f* ]] && force=1
        ;;
      *) targets+=("$w") ;;
    esac
  done
  if (( recursive && force )); then
    local t
    for t in "${targets[@]+"${targets[@]}"}"; do
      t=${t//\"/}
      t=${t//\'/}
      if [[ "$t" =~ $DANGEROUS_RM_TARGET ]]; then
        block "recursive force-delete of '$t'"
      fi
    done
  fi
}

# Split on command separators and check each segment.
segments=$command
for sep in '&&' '||' ';' '|' '&' '$(' '`' '(' ')'; do
  segments=${segments//"$sep"/$'\n'}
done
while IFS= read -r seg; do
  check_rm "$seg"
done <<<"$segments"

# git push --force / -f / +refspec (but not --force-with-lease). Finds the
# git subcommand by skipping global options, including those that take a
# value (-C <path>, -c <k=v>, --git-dir <dir>, --work-tree <dir>).
check_push() {
  local -a words
  read -r -a words <<<"$1"
  local i=0 n=${#words[@]}
  [[ "${words[0]:-}" == "sudo" ]] && i=1
  [[ "${words[$i]:-}" == "git" ]] || return 0
  i=$((i + 1))
  while (( i < n )); do
    case "${words[$i]}" in
      -C|-c|--git-dir|--work-tree|--namespace) i=$((i + 2)) ;;
      -*) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  [[ "${words[$i]:-}" == "push" ]] || return 0
  local w
  for w in "${words[@]:$((i + 1))}"; do
    case "$w" in
      --force|--force=*) block "force push (use --force-with-lease, or ask the user)" ;;
      --*) ;;
      -*f*) block "force push (use --force-with-lease, or ask the user)" ;;
      +*) block "force push via +refspec (use --force-with-lease, or ask the user)" ;;
    esac
  done
}

while IFS= read -r seg; do
  check_push "$seg"
done <<<"$segments"

# Fork bomb, raw writes to block devices, filesystem creation.
if printf '%s' "$command" | grep -qE ':\(\)[[:space:]]*\{.*:[[:space:]]*\|[[:space:]]*:.*&.*\}'; then
  block "fork bomb"
fi
if printf '%s' "$command" | grep -qE '(>|of=)[[:space:]]*/dev/(sd|nvme|disk|hd|xvd)'; then
  block "raw write to a block device"
fi
if printf '%s' "$command" | grep -qE '(^|[;&|[:space:]])(sudo[[:space:]]+)?mkfs(\.|[[:space:]])'; then
  block "filesystem creation"
fi

exit 0
