#!/usr/bin/env bash
set -euo pipefail

# Fork-local companion to scripts/link-skills.sh (upstream-owned, takes no
# arguments, links everything into ~/.claude/skills and ~/.agents/skills).
# This one asks where to link and which skills to link, interactively.
# deprecated/ is always excluded.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PI_DIR="$HOME/.pi/agent/skills"
PROJECT_DIR="$PWD/.agents/skills"

PRUNE=false
for arg in "$@"; do
  case "$arg" in
    --prune)
      PRUNE=true
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--prune]"
      echo "Interactively choose a destination and which skills to link into it."
      echo "Stale repo-owned links are always removed from the destination."
      echo "  --prune   also remove repo-owned links that are not in the selection"
      echo "            (interactive runs ask instead of needing this flag)"
      exit 0
      ;;
    *)
      echo "error: unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

# --- 1. destination --------------------------------------------------------

cat <<EOF
Link skills to:
  1) $PI_DIR (pi, global)
  2) $PROJECT_DIR (this project)
  3) custom path
EOF
read -rp "Choose [1]: " dest_choice
case "${dest_choice:-1}" in
  1) DEST="$PI_DIR" ;;
  2) DEST="$PROJECT_DIR" ;;
  3) read -rp "Path: " DEST ;;
  *) echo "error: unknown choice: $dest_choice" >&2; exit 1 ;;
esac

# Never write into this repo itself: that would drop symlinks into the
# tracked tree (e.g. choosing 2 while standing in the repo).
resolved_dest="$(readlink -f "$DEST" 2>/dev/null || echo "$DEST")"
case "$resolved_dest" in
  "$REPO"|"$REPO"/*)
    echo "error: $DEST resolves inside this repo; refusing." >&2
    exit 1
    ;;
esac

# --- 2. buckets ------------------------------------------------------------

# Preferred display order first, then any future bucket, deprecated excluded.
buckets=()
for b in engineering productivity in-progress misc; do
  [ -d "$REPO/skills/$b" ] && buckets+=("$b")
done
while IFS= read -r -d '' d; do
  name="$(basename "$d")"
  case " ${buckets[*]-} " in
    *" $name "*) ;;
    *) buckets+=("$name") ;;
  esac
done < <(find "$REPO/skills" -mindepth 1 -maxdepth 1 -type d -not -name deprecated -print0)

# Default: everything except misc.
default_buckets=""
for i in "${!buckets[@]}"; do
  [ "${buckets[$i]}" = misc ] || default_buckets="$default_buckets $((i + 1))"
done
default_buckets="${default_buckets# }"

bucket_labels=()
for i in "${!buckets[@]}"; do
  count="$(find "$REPO/skills/${buckets[$i]}" -name SKILL.md -not -path '*/node_modules/*' | wc -l)"
  bucket_labels+=("${buckets[$i]} ($count)")
done

# The tree TUI presents every bucket as an expandable row, so the numbered
# bucket filter below only applies to the fzf/numbered fallback paths.
USE_TUI=false
if [ -t 0 ] && [ -t 1 ] && command -v python3 >/dev/null && python3 -c 'import curses' 2>/dev/null; then
  USE_TUI=true
fi

chosen_buckets=()
if [ "$USE_TUI" = true ]; then
  chosen_buckets=("${buckets[@]}")
else
  echo ""
  echo "Buckets to pick from:"
  for i in "${!bucket_labels[@]}"; do
    echo "  $((i + 1))) ${bucket_labels[$i]}"
  done
  read -rp "Choose buckets (space-separated numbers) [$default_buckets]: " bucket_choice
  bucket_choice="${bucket_choice:-$default_buckets}"
  for n in $bucket_choice; do
    if [ "$n" -ge 1 ] && [ "$n" -le "${#buckets[@]}" ] 2>/dev/null; then
      chosen_buckets+=("${buckets[$((n - 1))]}")
    else
      echo "error: no bucket number $n" >&2
      exit 1
    fi
  done
fi

if [ "${#chosen_buckets[@]}" -eq 0 ]; then
  echo "No buckets selected; nothing linked."
  exit 0
fi

# --- 3. skills -------------------------------------------------------------

names=()
srcs=()
labels=()
for b in "${chosen_buckets[@]}"; do
  while IFS= read -r -d '' f; do
    src="$(dirname "$f")"
    names+=("$(basename "$src")")
    srcs+=("$src")
    labels+=("$b/$(basename "$src")")
  done < <(find "$REPO/skills/$b" -name SKILL.md -not -path '*/node_modules/*' -print0)
done

selected=()
tui_failed=false
if [ "$USE_TUI" = true ]; then
  if tui_out="$(python3 "$REPO/scripts/link-skills-tui.py" "$REPO" "$DEST")"; then
    while IFS= read -r line; do
      [ -n "$line" ] && selected+=("$line")
    done <<< "$tui_out"
  else
    rc=$?
    if [ "$rc" -eq 1 ]; then
      echo "Cancelled."
      exit 0
    fi
    tui_failed=true # rc 2: TUI unusable (tiny terminal etc.); fall through
  fi
fi
if [ "$USE_TUI" = false ] || [ "$tui_failed" = true ]; then
  if [ -t 0 ] && [ -t 1 ] && command -v fzf >/dev/null; then
    # Nothing pre-selected on purpose: load-time pre-selection in fzf races
    # with input loading (observed flaky even with --sync), so "all" is a
    # deterministic CTRL-A keypress instead.
    fzf_out="$(printf '%s\n' "${labels[@]}" | fzf --multi \
      --bind 'ctrl-a:select-all,ctrl-d:deselect-all' \
      --header='CTRL-A all, CTRL-D none, TAB toggle, ENTER confirm, ESC cancel' \
      --prompt='skills> ')" || fzf_out=""
    while IFS= read -r line; do
      [ -n "$line" ] && selected+=("$line")
    done <<< "$fzf_out"
  else
    # Non-interactive fallback: numbers, ranges, or 'all'.
    echo ""
    echo "Skills in ${chosen_buckets[*]}:"
    for i in "${!labels[@]}"; do
      echo "  $((i + 1))) ${labels[$i]}"
    done
    read -rp "Which skills? [all] (numbers/ranges, 'none' to cancel): " skill_choice
    skill_choice="${skill_choice:-all}"
    if [ "$skill_choice" = none ]; then
      selected=()
    elif [ "$skill_choice" = all ]; then
      selected=("${labels[@]}")
    else
      for token in $skill_choice; do
        case "$token" in
          *-*)
            lo="${token%-*}"; hi="${token#*-}"
            for ((n = lo; n <= hi; n++)); do selected+=("${labels[$((n - 1))]}"); done
            ;;
          *)
            selected+=("${labels[$((token - 1))]}")
            ;;
        esac
      done
    fi
  fi
fi

if [ "${#selected[@]}" -eq 0 ]; then
  echo "No skills selected; nothing linked."
  exit 0
fi

# --- 4. link ---------------------------------------------------------------

mkdir -p "$DEST"
linked=0
for label in "${selected[@]}"; do
  name="$(basename "$label")"
  # Find the src for this label.
  src=""
  for i in "${!labels[@]}"; do
    if [ "${labels[$i]}" = "$label" ]; then
      src="${srcs[$i]}"
      break
    fi
  done
  [ -n "$src" ] || { echo "error: unknown skill: $label" >&2; exit 1; }

  target="$DEST/$name"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    rm -rf "$target"
  fi
  ln -sfn "$src" "$target"
  echo "linked $name -> $src ($DEST)"
  linked=$((linked + 1))
done

# --- 5. cleanup --------------------------------------------------------------

keep_file="$(mktemp)"
trap 'rm -f "$keep_file"' EXIT
for label in "${selected[@]}"; do
  basename "$label" >> "$keep_file"
done

# Stale repo-owned links (renamed, deleted, or bucket-moved upstream) always go.
"$REPO/scripts/clean-skill-links.sh" "$DEST"

# Mirror mode: also drop repo-owned links outside the selection. Interactive
# runs confirm first; piped runs only when invoked with --prune.
if [ "$PRUNE" = true ]; then
  "$REPO/scripts/clean-skill-links.sh" --prune "$keep_file" "$DEST"
elif [ -t 0 ] && [ -t 1 ]; then
  candidates="$("$REPO/scripts/clean-skill-links.sh" --dry-run --prune "$keep_file" "$DEST")"
  if [ -n "$candidates" ]; then
    echo ""
    echo "$candidates"
    read -rp "Remove these from $DEST? [y/N] " yn
    case "$yn" in
      y|Y|yes) "$REPO/scripts/clean-skill-links.sh" --prune "$keep_file" "$DEST" ;;
      *) echo "Kept." ;;
    esac
  fi
fi

echo ""
echo "Linked $linked skill(s) into $DEST"
if [ "$DEST" = "$PI_DIR" ]; then
  echo "Note: pi loads skills at session start; open a new pi session to pick up changes."
fi
