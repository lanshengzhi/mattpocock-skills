#!/usr/bin/env python3
"""Tree picker for link-skills-to.sh.

Buckets render as expandable rows, skills as checkboxes underneath them.
Prints the confirmed selection to stdout as 'bucket/name' lines, one per
skill, so the calling shell script can map them back to source directories.

Exit codes: 0 confirmed (ENTER), 1 cancelled (q / ESC / Ctrl-C),
2 TUI unavailable (terminal too small, curses failure).
"""

import locale
import os
import sys

locale.setlocale(locale.LC_ALL, "")
os.environ.setdefault("ESCDELAY", "25")  # must be set before curses init, else ESC lags

import curses  # noqa: E402

PREFERRED_ORDER = ["engineering", "productivity", "in-progress", "misc"]
DEFAULT_SELECTED = {"engineering", "productivity", "in-progress"}
DEFAULT_EXPANDED = "engineering"

HELP = "j/k move  h/l collapse/expand  space toggle (bucket row: all)  enter done  q cancel"
MIN_HEIGHT = 8
MIN_WIDTH = 40


class TooSmall(Exception):
    pass


def find_buckets(repo):
    """Ordered (bucket, [skill names]) pairs, deprecated excluded."""
    root = os.path.join(repo, "skills")
    names = [
        d
        for d in os.listdir(root)
        if os.path.isdir(os.path.join(root, d)) and d != "deprecated"
    ]
    ordered = [b for b in PREFERRED_ORDER if b in names]
    ordered += sorted(n for n in names if n not in PREFERRED_ORDER)
    buckets = []
    for bucket in ordered:
        skills = []
        for dirpath, dirnames, filenames in os.walk(os.path.join(root, bucket)):
            dirnames[:] = [d for d in dirnames if d != "node_modules"]
            if "SKILL.md" in filenames:
                skills.append(os.path.basename(dirpath))
        buckets.append((bucket, sorted(skills)))
    return buckets


def build_rows(buckets, expanded):
    rows = []
    for bi, (bucket, skills) in enumerate(buckets):
        rows.append(("bucket", bi))
        if expanded[bucket]:
            rows.extend(("skill", bi, s) for s in skills)
    return rows


def seed_selected(buckets, dest, repo):
    """Initial selection: the skills currently linked in dest. A dest with
    no repo-owned links at all (fresh install) gets the default buckets."""
    prefix = os.path.join(repo, "skills") + os.sep
    linked = set()
    if os.path.isdir(dest):
        for entry in os.listdir(dest):
            path = os.path.join(dest, entry)
            if os.path.islink(path) and os.readlink(path).startswith(prefix):
                linked.add(entry)
    if not linked:
        return {
            (b, s) for b, skills in buckets if b in DEFAULT_SELECTED for s in skills
        }
    return {(b, s) for b, skills in buckets for s in skills if s in linked}


def run(stdscr, buckets, dest, repo):
    try:
        curses.curs_set(0)
    except curses.error:
        pass
    stdscr.keypad(True)

    expanded = {b: b == DEFAULT_EXPANDED for b, _ in buckets}
    selected = seed_selected(buckets, dest, repo)
    cursor = 0
    offset = 0

    while True:
        maxy, maxx = stdscr.getmaxyx()
        if maxy < MIN_HEIGHT or maxx < MIN_WIDTH:
            raise TooSmall

        rows = build_rows(buckets, expanded)
        cursor = max(0, min(cursor, len(rows) - 1))
        body_top = 2
        body_height = maxy - body_top - 1
        if cursor < offset:
            offset = cursor
        elif cursor >= offset + body_height:
            offset = cursor - body_height + 1

        stdscr.erase()
        header = f"Select skills to link into: {dest}  ({len(selected)} selected)"
        stdscr.addnstr(0, 0, header, maxx - 1, curses.A_BOLD)

        for screen_y, row in enumerate(rows[offset : offset + body_height]):
            y = body_top + screen_y
            attr = curses.A_REVERSE if offset + screen_y == cursor else curses.A_NORMAL
            if row[0] == "bucket":
                bi = row[1]
                bucket, skills = buckets[bi]
                marker = "▾" if expanded[bucket] else "▸"
                nsel = sum(1 for s in skills if (bucket, s) in selected)
                text = f"{marker} {bucket} ({nsel}/{len(skills)})"
                stdscr.addnstr(y, 0, text, maxx - 1, attr | curses.A_BOLD)
            else:
                _, bi, skill = row
                bucket = buckets[bi][0]
                mark = "x" if (bucket, skill) in selected else " "
                stdscr.addnstr(y, 2, f"[{mark}] {skill}", maxx - 3, attr)

        stdscr.addnstr(maxy - 1, 0, HELP, maxx - 1, curses.A_DIM)
        stdscr.refresh()

        ch = stdscr.getch()
        if ch in (ord("q"), 27):
            return None
        if ch in (10, 13, curses.KEY_ENTER):
            return selected
        if ch in (ord("k"), curses.KEY_UP):
            cursor -= 1
        elif ch in (ord("j"), curses.KEY_DOWN):
            cursor += 1
        elif ch in (ord("l"), curses.KEY_RIGHT, 9):
            row = rows[cursor]
            if row[0] == "bucket":
                expanded[buckets[row[1]][0]] = True
        elif ch in (ord("h"), curses.KEY_LEFT):
            row = rows[cursor]
            if row[0] == "bucket":
                expanded[buckets[row[1]][0]] = False
        elif ch == ord(" "):
            row = rows[cursor]
            if row[0] == "bucket":
                bucket, skills = buckets[row[1]]
                keys = {(bucket, s) for s in skills}
                if keys <= selected:
                    selected -= keys
                else:
                    selected |= keys
            else:
                key = (buckets[row[1]][0], row[2])
                if key in selected:
                    selected.discard(key)
                else:
                    selected.add(key)
        # KEY_RESIZE and anything else: just re-render


def main():
    if len(sys.argv) < 2:
        print("usage: link-skills-tui.py REPO [DEST]", file=sys.stderr)
        sys.exit(2)
    repo = sys.argv[1]
    dest = sys.argv[2] if len(sys.argv) > 2 else ""
    buckets = find_buckets(repo)
    if not any(skills for _, skills in buckets):
        sys.exit(2)
    # curses draws on stdout, but the caller captures stdout via $(...).
    # Move the UI to the controlling terminal (like fzf does) and keep the
    # real stdout for the result lines only.
    real_stdout = os.dup(1)
    try:
        tty = os.open("/dev/tty", os.O_RDWR)
    except OSError:
        sys.exit(2)
    os.dup2(tty, 1)
    os.close(tty)
    try:
        result = curses.wrapper(lambda stdscr: run(stdscr, buckets, dest, repo))
    except (curses.error, TooSmall):
        sys.exit(2)
    except KeyboardInterrupt:
        sys.exit(1)
    if result is None:
        sys.exit(1)
    with os.fdopen(real_stdout, "w") as out:
        for bucket, skills in buckets:
            for skill in skills:
                if (bucket, skill) in result:
                    print(f"{bucket}/{skill}", file=out)


if __name__ == "__main__":
    main()
