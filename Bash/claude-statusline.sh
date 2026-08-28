#!/usr/bin/env bash
#
# claude-statusline.sh - live Claude Code status line: plan usage, context, cost, churn.
#
# Description: Renders one status line for Claude Code. Reads the Status JSON on
#              stdin and the session transcript for token counts. Shows the same
#              5h/weekly plan-usage percentages as /usage (when present), plus
#              context-window fill, session cost and lines changed. Needs jq.
#              No strict mode by design: missing fields must degrade gracefully.
# Usage:       Wire up in ~/.claude/settings.json:
#              "statusLine": { "type": "command",
#                "command": "bash ~/Git/GitHub/segraef/Scripts/Bash/claude-statusline.sh" }
# Author:      Sebastian Gräf
# Repo:        https://github.com/segraef/Scripts

input=$(cat)

model_name=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')
model_id=$(printf '%s' "$input" | jq -r '.model.id // ""')
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // ""')
cost=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // 0')
added=$(printf '%s' "$input" | jq -r '.cost.total_lines_added // 0')
removed=$(printf '%s' "$input" | jq -r '.cost.total_lines_removed // 0')
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // ""')
# Reasoning effort (/effort). Only present when the model supports it, so the
# whole segment is omitted rather than printing an empty label. Note the field
# reports the underlying tier: an "ultracode" session shows as xhigh.
effort=$(printf '%s' "$input" | jq -r '.effort.level // empty')

# Plan rate-limit usage — the same numbers /usage shows. Present only for
# Claude.ai Pro/Max sessions, and only after the first API response.
h5=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
wk=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)

# Write the two percentages down as well as drawing them, so an agent session
# can read its own budget. The CLI hands these to this script on stdin and keeps
# no live copy: the one on disk (~/.claude.json cachedUsageUtilization) is a
# cache that has been seen two days stale, reading 74% against a real 92%, which
# is worse than having nothing. This file is rewritten every render.
if [ -n "$h5" ] || [ -n "$wk" ]; then
  printf '{"five_hour_pct":%s,"seven_day_pct":%s,"written_at":"%s"}\n' \
    "${h5:-null}" "${wk:-null}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    > "$HOME/.claude/usage-live.json" 2>/dev/null || true
fi

# Colour a usage percentage by pressure. Usage: colour_for <pct>
colour_for() {
  if   [ "$1" -ge 90 ]; then printf '\033[31m'   # red
  elif [ "$1" -ge 70 ]; then printf '\033[33m'   # yellow
  else printf '\033[32m'; fi                      # green
}

# Context window size: 1M for [1m] models, else 200k.
case "$model_id" in
  *1m*|*\[1m\]*) window=1000000 ;;
  *) window=200000 ;;
esac

# Latest context size = last assistant usage in the transcript.
used=0
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  reverse_cmd="tail -r"; command -v tac >/dev/null 2>&1 && reverse_cmd="tac"
  used=$($reverse_cmd "$transcript" 2>/dev/null | jq -r '
    select(.message.usage != null)
    | (.message.usage.input_tokens // 0)
      + (.message.usage.cache_read_input_tokens // 0)
      + (.message.usage.cache_creation_input_tokens // 0)' 2>/dev/null \
    | head -n1)
  [ -z "$used" ] && used=0
fi

pct=$(( used * 100 / window ))
[ "$pct" -gt 100 ] && pct=100

# Colour the context segment by pressure.
if   [ "$pct" -ge 85 ]; then cx="\033[31m"   # red
elif [ "$pct" -ge 60 ]; then cx="\033[33m"   # yellow
else cx="\033[32m"; fi                        # green
dim="\033[2m"; rst="\033[0m"

usedk=$(( used / 1000 ))
wink=$(( window / 1000 ))

dir=$(basename "$cwd")
costfmt=$(printf '%.2f' "$cost")

# Effort segment. Colour rises with the tier so a costly setting is visible at a
# glance rather than something you have to remember you left on.
effort_seg=""
if [ -n "$effort" ]; then
  case "$effort" in
    max)          ec="\033[35m" ;;  # magenta
    xhigh)        ec="\033[31m" ;;  # red
    high)         ec="\033[33m" ;;  # yellow
    medium)       ec="\033[32m" ;;  # green
    *)            ec="\033[2m"  ;;  # dim for low
  esac
  effort_seg="${ec}${effort}${rst} ${dim}|${rst} "
fi

# Build the plan-usage segment when the data is present.
usage_seg=""
if [ -n "$h5" ] || [ -n "$wk" ]; then
  [ -z "$h5" ] && h5=0
  [ -z "$wk" ] && wk=0
  c5=$(colour_for "$h5"); cw=$(colour_for "$wk")
  usage_seg="${c5}5h ${h5}%${rst} ${dim}·${rst} ${cw}wk ${wk}%${rst} ${dim}|${rst} "
fi

printf "%b %s${dim}|${rst} %b%b${cx}ctx %s%% (%dk/%dk)${rst} ${dim}|${rst} \$%s ${dim}|${rst} ${dim}+%s/-%s${rst} ${dim}%s${rst}" \
  "🧠" "$model_name" "$effort_seg" "$usage_seg" "$pct" "$usedk" "$wink" "$costfmt" "$added" "$removed" "$dir"
