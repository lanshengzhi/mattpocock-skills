#!/usr/bin/env bash
set -euo pipefail

# Removes repo-owned symlinks from a skills destination directory.
# Repo-owned means: a symlink whose target text starts with "$REPO/skills/".
# Real directories and symlinks pointing elsewhere are never touched.
#
# Stale links (target no longer exists, e.g. after an upstream rename,
# deletion, or bucket move) are always removed. With --prune, links whose
# skill name is not in the given keep-file are removed too, so the
# destination mirrors the selection.
#
# Usage: clean-skill-links.sh [--prune KEEP_FILE] [--dry-run] DEST

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="$REPO/skills/"

PRUNE_FILE=""
DRY_RUN=false
DEST=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --prune)
      PRUNE_FILE="${2:?--prune needs a keep-file argument}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--prune KEEP_FILE] [--dry-run] DEST"
      exit 0
      ;;
    *)
      DEST="$1"
      shift
      ;;
  esac
done

[ -n "$DEST" ] || { echo "error: missing DEST (see --help)" >&2; exit 1; }
[ -d "$DEST" ] || { echo "error: no such directory: $DEST" >&2; exit 1; }

declare -A keep=()
if [ -n "$PRUNE_FILE" ]; then
  while IFS= read -r name; do
    [ -n "$name" ] && keep["$name"]=1
  done < "$PRUNE_FILE"
fi

shopt -s nullglob
for entry in "$DEST"/*; do
  [ -L "$entry" ] || continue
  target="$(readlink "$entry")"
  case "$target" in
    "$PREFIX"*) ;;
    *) continue ;;
  esac
  name="$(basename "$entry")"
  reason=""
  if [ ! -e "$entry" ]; then
    reason="stale: target gone"
  elif [ -n "$PRUNE_FILE" ] && [ -z "${keep[$name]:-}" ]; then
    reason="not selected"
  fi
  [ -n "$reason" ] || continue
  if [ "$DRY_RUN" = true ]; then
    echo "would remove: $name ($reason)"
  else
    rm "$entry"
    echo "removed: $name ($reason)"
  fi
done
