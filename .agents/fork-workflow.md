# Fork workflow

This repository keeps upstream code on `main` and fork-specific changes on `custom`.

## Before changing files

- Verify the current branch before editing, committing, pushing, or syncing.
- Make custom changes only on `custom`.
- Keep `main` identical to `upstream/main`; use it only as the rebase base.
- Prefer fork-only files when practical. Changes to upstream-maintained files belong on `custom` and may require conflict resolution during later rebases.

## Syncing upstream

- Run `scripts/sync-upstream.sh` only when the user explicitly asks to sync upstream.
- Treat `scripts/sync-upstream.sh` as the source of truth for fetch, fast-forward, rebase, and push mechanics. Do not duplicate its command sequence here.
- Use `--no-push` when the user asks for a local sync without remote updates.

If a manual rebase requires updating `origin/custom`, use `git push --force-with-lease origin custom`.

Only push when the user explicitly requests the remote update.
