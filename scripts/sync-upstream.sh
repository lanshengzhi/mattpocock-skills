#!/usr/bin/env bash
set -euo pipefail

# Configuration
MAIN_BRANCH="main"
CUSTOM_BRANCH="custom"
UPSTREAM_REMOTE="upstream"
ORIGIN_REMOTE="origin"

# Flags
PUSH=true
for arg in "$@"; do
  case "$arg" in
    --no-push)
      PUSH=false
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--no-push]"
      echo "Synchronizes '$MAIN_BRANCH' with '$UPSTREAM_REMOTE/$MAIN_BRANCH' and '$ORIGIN_REMOTE/$MAIN_BRANCH',"
      echo "then rebases '$CUSTOM_BRANCH' onto '$MAIN_BRANCH' and pushes to '$ORIGIN_REMOTE/$CUSTOM_BRANCH'."
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      exit 1
      ;;
  esac
done

echo "==> 1. Checking git status..."
if ! git diff-index --quiet HEAD --; then
  echo "Error: Working directory has uncommitted changes. Please commit or stash them first." >&2
  exit 1
fi

echo "==> 2. Fetching from '$UPSTREAM_REMOTE' and '$ORIGIN_REMOTE'..."
git fetch "$UPSTREAM_REMOTE"
git fetch "$ORIGIN_REMOTE"

echo "==> 3. Updating '$MAIN_BRANCH' to match '$UPSTREAM_REMOTE/$MAIN_BRANCH'..."
git checkout "$MAIN_BRANCH"
git merge --ff-only "$UPSTREAM_REMOTE/$MAIN_BRANCH"

if [ "$PUSH" = true ]; then
  echo "==> 4. Pushing updated '$MAIN_BRANCH' to '$ORIGIN_REMOTE/$MAIN_BRANCH'..."
  git push "$ORIGIN_REMOTE" "$MAIN_BRANCH"
else
  echo "==> 4. Skipping push for '$MAIN_BRANCH' (--no-push active)..."
fi

echo "==> 5. Rebasing '$CUSTOM_BRANCH' onto '$MAIN_BRANCH'..."
git checkout "$CUSTOM_BRANCH"
if ! git rebase "$MAIN_BRANCH"; then
  echo "" >&2
  echo "=================================================================" >&2
  echo "Conflict detected during rebase!" >&2
  echo "1. Resolve the conflicts in your editor" >&2
  echo "2. Stage resolved files: git add <file>" >&2
  echo "3. Continue rebase:      git rebase --continue" >&2
  echo "4. Push once done:       git push $ORIGIN_REMOTE $CUSTOM_BRANCH --force-with-lease" >&2
  echo "=================================================================" >&2
  exit 1
fi

if [ "$PUSH" = true ]; then
  echo "==> 6. Pushing rebased '$CUSTOM_BRANCH' to '$ORIGIN_REMOTE/$CUSTOM_BRANCH'..."
  git push "$ORIGIN_REMOTE" "$CUSTOM_BRANCH" --force-with-lease
else
  echo "==> 6. Skipping push for '$CUSTOM_BRANCH' (--no-push active)..."
fi

echo "==> Done! '$CUSTOM_BRANCH' is now up-to-date with upstream changes on top."
