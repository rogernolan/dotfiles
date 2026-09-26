#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
INSTALLER="$SCRIPT_DIR/install-macos.sh"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_file_exists() {
    [[ -e "$1" || -L "$1" ]] || fail "expected path: $1"
}

assert_file_absent() {
    [[ ! -e "$1" && ! -L "$1" ]] || fail "did not expect path: $1"
}

assert_symlink_to() {
    [[ -L "$1" ]] || fail "expected symlink: $1"
    [[ "$(readlink "$1")" == "$2" ]] || fail "expected $1 -> $2, got $(readlink "$1")"
}

assert_contains() {
    grep -Fq -- "$1" "$2" || fail "expected '$1' in $2"
}

assert_count() {
    local expected=$1 pattern=$2 file=$3 actual
    actual=$(grep -Fc -- "$pattern" "$file" 2>/dev/null || true)
    [[ "$actual" -eq "$expected" ]] || fail "expected $expected occurrences of '$pattern' in $file, got $actual"
}

make_fixture() {
    FIXTURE=$(mktemp -d)
    HOME_DIR="$FIXTURE/home"
    BIN="$FIXTURE/bin"
    mkdir -p "$HOME_DIR/.config/opencode" "$HOME_DIR/.ssh" "$BIN"
    printf 'provider = preserved\n' > "$HOME_DIR/.config/opencode/config.toml"
    printf 'ssh-ed25519 preserved\n' > "$HOME_DIR/.ssh/authorized_keys"

    cat > "$BIN/brew" <<'BREW'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$FAKE_BREW_LOG"
if [[ "${1:-}" == bundle && "${2:-}" == check ]]; then
    [[ -f "$FAKE_BREW_SATISFIED" ]]
    exit
fi
if [[ "${1:-}" == bundle && "${2:-}" == install ]]; then
    touch "$FAKE_BREW_SATISFIED"
fi
BREW
    chmod +x "$BIN/brew"

    LEGACY_DIR="$FIXTURE/legacy"
    mkdir -p "$LEGACY_DIR/oh-my-zsh"
    printf 'export LEGACY_PRIVATE=1\n' > "$LEGACY_DIR/private"
    chmod 0600 "$LEGACY_DIR/private"
    ln -s "$LEGACY_DIR/private" "$HOME_DIR/.private"
    ln -s "$LEGACY_DIR/oh-my-zsh" "$HOME_DIR/.oh-my-zsh"
    for name in bashrc gitconfig gitignore_global vimrc zshrc; do
        ln -s "$LEGACY_DIR/$name" "$HOME_DIR/.$name"
    done
    printf 'legacy tmux\n' > "$HOME_DIR/.tmux.conf"

    BREW_LOG="$FIXTURE/brew.log"
    : > "$BREW_LOG"
    BREW_SATISFIED="$FIXTURE/brew-satisfied"
}

run_installer() {
    DOTFILES_HOME="$HOME_DIR" \
    DOTFILES_BREW="$BIN/brew" \
    DOTFILES_TEST_MODE=1 \
    FAKE_BREW_LOG="$BREW_LOG" \
    FAKE_BREW_SATISFIED="$BREW_SATISFIED" \
    PATH="$BIN:/usr/bin:/bin" \
        "$INSTALLER" "$@" > "$FIXTURE/output" 2>&1
}

test_mode_requires_explicit_brew() {
    make_fixture
    if DOTFILES_HOME="$HOME_DIR" \
        DOTFILES_TEST_MODE=1 \
        FAKE_BREW_LOG="$BREW_LOG" \
        FAKE_BREW_SATISFIED="$BREW_SATISFIED" \
        PATH="$BIN:/usr/bin:/bin" \
        "$INSTALLER" > "$FIXTURE/output" 2>&1; then
        fail 'test mode accepted a missing DOTFILES_BREW'
    fi
    assert_contains 'DOTFILES_BREW is required in test mode' "$FIXTURE/output"
    [[ ! -s "$BREW_LOG" ]] || fail 'test mode discovered and invoked Homebrew'
    rm -rf "$FIXTURE"
}

backup_path() {
    local name=$1
    find "$HOME_DIR/dotfiles-migration-backups" -mindepth 2 -maxdepth 2 -name "$name" -print -quit 2>/dev/null
}

test_dry_run_does_not_mutate() {
    make_fixture
    run_installer --dry-run
    assert_symlink_to "$HOME_DIR/.zshrc" "$LEGACY_DIR/zshrc"
    assert_file_exists "$HOME_DIR/.private"
    assert_file_exists "$HOME_DIR/.oh-my-zsh"
    assert_file_absent "$HOME_DIR/dotfiles-migration-backups"
    [[ ! -s "$BREW_LOG" ]] || fail 'dry-run invoked Homebrew'
    rm -rf "$FIXTURE"
}

test_first_install_backs_up_legacy_links_and_preserves_unrelated_files() {
    make_fixture
    run_installer
    assert_symlink_to "$HOME_DIR/.zprofile" "$SCRIPT_DIR/config/zprofile"
    assert_symlink_to "$HOME_DIR/.zshrc" "$SCRIPT_DIR/config/zshrc"
    assert_symlink_to "$HOME_DIR/.gitconfig" "$SCRIPT_DIR/config/gitconfig"
    assert_symlink_to "$HOME_DIR/.gitignore_global" "$SCRIPT_DIR/config/gitignore_global"
    assert_symlink_to "$HOME_DIR/.vimrc" "$SCRIPT_DIR/config/vimrc"
    assert_symlink_to "$HOME_DIR/.bashrc" "$SCRIPT_DIR/config/bashrc"
    assert_symlink_to "$HOME_DIR/.tmux.conf" "$SCRIPT_DIR/config/tmux.conf"
    assert_symlink_to "$HOME_DIR/.config/fish/config.fish" "$SCRIPT_DIR/config/fish/config.fish"
    assert_file_absent "$HOME_DIR/.private"
    assert_file_absent "$HOME_DIR/.oh-my-zsh"
    assert_file_exists "$HOME_DIR/.config/rog/private"
    [[ "$(stat -f '%Lp' "$HOME_DIR/.config/rog/private")" == 600 ]] || fail 'private file mode was not preserved'
    assert_contains 'export LEGACY_PRIVATE=1' "$HOME_DIR/.config/rog/private"
    assert_contains 'ssh-ed25519 preserved' "$HOME_DIR/.ssh/authorized_keys"
    assert_contains 'provider = preserved' "$HOME_DIR/.config/opencode/config.toml"
    assert_file_exists "$(backup_path .zshrc)"
    assert_file_exists "$(backup_path .private)"
    assert_file_exists "$(backup_path .oh-my-zsh)"
    assert_file_exists "$(backup_path .tmux.conf)"
    assert_contains 'bundle check' "$BREW_LOG"
    assert_contains 'bundle install' "$BREW_LOG"
    rm -rf "$FIXTURE"
}

test_second_install_is_idempotent() {
    make_fixture
    run_installer
    backup_count=$(find "$HOME_DIR/dotfiles-migration-backups" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
    run_installer
    second_backup_count=$(find "$HOME_DIR/dotfiles-migration-backups" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
    [[ "$backup_count" == 1 && "$second_backup_count" == 1 ]] || fail 'repeat install created extra backups'
    assert_count 1 'bundle install' "$BREW_LOG"
    rm -rf "$FIXTURE"
}

test_no_migrate_leaves_private_and_oh_my_zsh_untouched() {
    make_fixture
    run_installer --no-migrate
    assert_file_exists "$HOME_DIR/.private"
    assert_file_exists "$HOME_DIR/.oh-my-zsh"
    assert_file_absent "$HOME_DIR/.config/rog/private"
    rm -rf "$FIXTURE"
}

test_unmanaged_files_are_backed_up_before_replacement() {
    make_fixture
    printf 'unmanaged tmux\n' > "$HOME_DIR/.tmux.conf"
    run_installer
    assert_contains 'unmanaged tmux' "$(backup_path .tmux.conf)"
    assert_symlink_to "$HOME_DIR/.tmux.conf" "$SCRIPT_DIR/config/tmux.conf"
    rm -rf "$FIXTURE"
}

test_dry_run_does_not_mutate
test_mode_requires_explicit_brew
test_first_install_backs_up_legacy_links_and_preserves_unrelated_files
test_second_install_is_idempotent
test_no_migrate_leaves_private_and_oh_my_zsh_untouched
test_unmanaged_files_are_backed_up_before_replacement
printf 'PASS: macOS installer tests\n'
