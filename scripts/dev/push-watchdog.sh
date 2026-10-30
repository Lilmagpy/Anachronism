#!/bin/bash
# Safety net (D-293): every 5 minutes, push any claude/* branch checked out in a worktree under
# /home/user that has commits the remote lacks. Agents push themselves; this catches the ones
# that forget. Run it in the background: nohup scripts/dev/push-watchdog.sh >/tmp/claude-0/watchdog.log 2>&1 &
while true; do
  for wt in /home/user/anachronism /home/user/u8-* /home/user/r*-*; do
    [ -d "$wt/.git" ] || [ -f "$wt/.git" ] || continue
    br=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)
    case "$br" in claude/*) ;; *) continue ;; esac
    [ "$br" = "main" ] && continue
    remote=$(git -C "$wt" rev-parse -q --verify "origin/$br" 2>/dev/null)
    local=$(git -C "$wt" rev-parse HEAD)
    if [ "$remote" != "$local" ] && [ -z "$(git -C "$wt" rev-list -n1 "$local..origin/$br" 2>/dev/null)" ]; then
      git -C "$wt" push -q -u origin "$br" 2>/dev/null && echo "$(date -u +%H:%M) pushed $br ${local:0:7}"
    fi
  done
  sleep 300
done
