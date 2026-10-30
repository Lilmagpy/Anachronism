#!/bin/bash
# Safety net (D-293): every 5 minutes, for every claude/* worktree under /home/user:
#  1. push the branch if it has commits the remote lacks (agents push themselves; this catches
#     the ones that forget);
#  2. snapshot uncommitted and untracked files into a commit on `<branch>-wip` and push that,
#     using a private index so the agent's working tree, index and branch are never touched.
# Run it in the background: nohup scripts/dev/push-watchdog.sh >/tmp/claude-0/watchdog.log 2>&1 &
# Recover a snapshot: git fetch origin <branch>-wip && git checkout origin/<branch>-wip -- .
while true; do
  for wt in /home/user/anachronism /home/user/u8-* /home/user/r*-*; do
    [ -e "$wt/.git" ] || continue
    br=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)
    case "$br" in claude/*) ;; *) continue ;; esac
    head=$(git -C "$wt" rev-parse HEAD)
    remote=$(git -C "$wt" ls-remote origin "refs/heads/$br" 2>/dev/null | cut -f1)
    if [ "$remote" != "$head" ] && { [ -z "$remote" ] || git -C "$wt" merge-base --is-ancestor "$remote" "$head" 2>/dev/null; }; then
      git -C "$wt" push -q -u origin "$br" 2>/dev/null && echo "$(date -u +%H:%M) pushed $br ${head:0:7}"
    fi
    if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then
      idx=$(mktemp)
      tree=$(cd "$wt" && GIT_INDEX_FILE=$idx git read-tree HEAD && GIT_INDEX_FILE=$idx git add -A . && GIT_INDEX_FILE=$idx git write-tree)
      rm -f "$idx"
      last=$(cat "/tmp/claude-0/wip.${br//\//_}" 2>/dev/null)
      if [ -n "$tree" ] && [ "$tree" != "$last" ]; then
        c=$(git -C "$wt" commit-tree "$tree" -p "$head" -m "WIP snapshot of $br by push-watchdog $(date -u +%FT%TZ)")
        git -C "$wt" push -q -f origin "$c:refs/heads/$br-wip" 2>/dev/null && echo "$tree" > "/tmp/claude-0/wip.${br//\//_}" && echo "$(date -u +%H:%M) snapshot $br-wip ${c:0:7}"
      fi
    fi
  done
  sleep 300
done
