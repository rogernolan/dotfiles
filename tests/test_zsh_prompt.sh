#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
ZSHRC="$SCRIPT_DIR/config/zshrc"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_equals() {
    local expected=$1 actual=$2 description=$3
    [[ "$actual" == "$expected" ]] || fail "$description: expected '$expected', got '$actual'"
}

FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT

HOME_DIR="$FIXTURE/home"
REPO="$FIXTURE/repo"
mkdir -p "$HOME_DIR" "$REPO"

git -C "$REPO" init -q
git -C "$REPO" config user.name 'Prompt Test'
git -C "$REPO" config user.email 'prompt@example.test'
printf 'tracked\n' > "$REPO/tracked.txt"
git -C "$REPO" add tracked.txt
git -C "$REPO" commit -q -m initial
git -C "$REPO" branch -M main

run_prompt() {
    local directory=$1
    (
        cd "$directory"
        HOME="$HOME_DIR" ZDOTDIR="$FIXTURE/zdotdir" \
            zsh -dfc 'source "$1"; dotfiles_git_prompt' zsh "$ZSHRC"
    )
}

assert_equals '' "$(run_prompt "$HOME_DIR")" 'non-repository prompt segment'
assert_equals ' (main)' "$(run_prompt "$REPO")" 'clean repository prompt segment'

printf 'changed\n' >> "$REPO/tracked.txt"
assert_equals ' (main ✗)' "$(run_prompt "$REPO")" 'tracked changes prompt segment'

git -C "$REPO" checkout -q -- .
printf 'untracked\n' > "$REPO/untracked.txt"
assert_equals ' (main ✗)' "$(run_prompt "$REPO")" 'untracked changes prompt segment'

git -C "$REPO" add untracked.txt
git -C "$REPO" commit -q -m second
git -C "$REPO" checkout -q --detach HEAD
assert_equals " ($(git -C "$REPO" rev-parse --short HEAD))" "$(run_prompt "$REPO")" 'detached HEAD prompt segment'

printf 'PASS: zsh prompt tests\n'
