#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
INSTALLER="$SCRIPT_DIR/install-macos.sh"
REAL_GIT=$(command -v git)
SKILLS_URL=https://github.com/rogernolan/rog-skills.git
trap '[[ -z ${FIXTURE:-} ]] || rm -rf "$FIXTURE"' EXIT

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

    SKILLS_REPO="$HOME_DIR/Development/rog-skills"
    SKILLS_REMOTE="$FIXTURE/skills-remote.git"
    SKILLS_SEED="$FIXTURE/skills-seed"
    GIT_LOG="$FIXTURE/git.log"
    : > "$GIT_LOG"
    DENY_ACCESS=0
    HOMELAB_SKILL="$HOME_DIR/Development/tob-lxc-setup/skills/homelab-admin"
    mkdir -p "$HOMELAB_SKILL"
    printf '# Homelab Admin\n' > "$HOMELAB_SKILL/SKILL.md"
    "$REAL_GIT" init -q "$SKILLS_SEED"
    "$REAL_GIT" -C "$SKILLS_SEED" config user.name 'Installer Test'
    "$REAL_GIT" -C "$SKILLS_SEED" config user.email installer@example.test
    "$REAL_GIT" -C "$SKILLS_SEED" branch -M main
    mkdir -p "$SKILLS_SEED/skills/technical-writing" "$SKILLS_SEED/skills/another-skill" "$SKILLS_SEED/skills/not-a-skill"
    printf '# Technical Writing\n' > "$SKILLS_SEED/skills/technical-writing/SKILL.md"
    printf '# Another Skill\n' > "$SKILLS_SEED/skills/another-skill/SKILL.md"
    printf 'not a skill\n' > "$SKILLS_SEED/skills/not-a-skill/README.md"
    "$REAL_GIT" -C "$SKILLS_SEED" add .
    "$REAL_GIT" -C "$SKILLS_SEED" commit -qm initial
    "$REAL_GIT" clone -q --bare "$SKILLS_SEED" "$SKILLS_REMOTE"

    cat > "$BIN/git" <<'GIT'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$FAKE_GIT_LOG"
case " $* " in
    *' ls-remote '*|*' clone '*|*' pull '*|*' fetch '*)
        [[ ${GIT_TERMINAL_PROMPT:-} == 0 ]] || { echo 'unexpected interactive Git access' >&2; exit 90; }
        [[ ${FAKE_GIT_DENY_ACCESS:-0} == 0 ]] || { echo 'mock private repository access denied' >&2; exit 128; }
        ;;
esac
exec "$REAL_GIT" -c "url.$FAKE_SKILLS_REMOTE.insteadOf=https://github.com/rogernolan/rog-skills.git" "$@"
GIT
    cat > "$BIN/gh" <<'GH'
#!/usr/bin/env bash
echo 'installer must not invoke interactive authentication' >&2
exit 91
GH
    chmod +x "$BIN/git" "$BIN/gh"
}

run_installer() {
    DOTFILES_HOME="$HOME_DIR" \
    DOTFILES_BREW="$BIN/brew" \
    DOTFILES_TEST_MODE=1 \
    FAKE_BREW_LOG="$BREW_LOG" \
    FAKE_BREW_SATISFIED="$BREW_SATISFIED" \
    REAL_GIT="$REAL_GIT" \
    FAKE_SKILLS_REMOTE="$SKILLS_REMOTE" \
    FAKE_GIT_LOG="$GIT_LOG" \
    FAKE_GIT_DENY_ACCESS="$DENY_ACCESS" \
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

clone_existing_skills() {
    mkdir -p "$(dirname "$SKILLS_REPO")"
    "$REAL_GIT" clone -q "$SKILLS_REMOTE" "$SKILLS_REPO"
    "$REAL_GIT" -C "$SKILLS_REPO" remote set-url origin "$SKILLS_URL"
    "$REAL_GIT" -C "$SKILLS_REPO" config user.name 'Installer Test'
    "$REAL_GIT" -C "$SKILLS_REPO" config user.email installer@example.test
}

advance_skills_remote() {
    printf 'upstream addition\n' >> "$SKILLS_SEED/skills/another-skill/SKILL.md"
    "$REAL_GIT" -C "$SKILLS_SEED" commit -qam upstream
    "$REAL_GIT" -C "$SKILLS_SEED" push -q "$SKILLS_REMOTE" main
}

skill_backup_path() {
    find "$HOME_DIR/dotfiles-migration-backups" -path "*/$1" -print -quit
}

expect_install_failure() {
    if run_installer; then
        fail 'expected installer failure'
    fi
    assert_contains 'ERROR:' "$FIXTURE/output"
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

test_fresh_skills_installation() {
    make_fixture
    run_installer
    assert_symlink_to "$HOME_DIR/.agents/skills/technical-writing" "$SKILLS_REPO/skills/technical-writing"
    assert_symlink_to "$HOME_DIR/.agents/skills/another-skill" "$SKILLS_REPO/skills/another-skill"
    assert_symlink_to "$HOME_DIR/.codex/skills/technical-writing" "$SKILLS_REPO/skills/technical-writing"
    assert_symlink_to "$HOME_DIR/.codex/skills/another-skill" "$SKILLS_REPO/skills/another-skill"
    assert_symlink_to "$HOME_DIR/.agents/skills/homelab-admin" "$HOMELAB_SKILL"
    assert_symlink_to "$HOME_DIR/.codex/skills/homelab-admin" "$HOMELAB_SKILL"
    assert_file_absent "$HOME_DIR/.agents/skills/not-a-skill"
    assert_file_absent "$HOME_DIR/.codex/skills/not-a-skill"
    assert_contains "clone $SKILLS_URL $SKILLS_REPO" "$GIT_LOG"
}

test_repeat_skills_installation_keeps_links() {
    make_fixture
    run_installer
    local inode
    inode=$(stat -f '%i' "$HOME_DIR/.agents/skills/technical-writing")
    local codex_inode homelab_inode
    codex_inode=$(stat -f '%i' "$HOME_DIR/.codex/skills/technical-writing")
    homelab_inode=$(stat -f '%i' "$HOME_DIR/.codex/skills/homelab-admin")
    run_installer
    [[ $(stat -f '%i' "$HOME_DIR/.agents/skills/technical-writing") == "$inode" ]] || fail 'correct skill link was replaced'
    [[ $(stat -f '%i' "$HOME_DIR/.codex/skills/technical-writing") == "$codex_inode" ]] || fail 'correct Codex skill link was replaced'
    [[ $(stat -f '%i' "$HOME_DIR/.codex/skills/homelab-admin") == "$homelab_inode" ]] || fail 'correct homelab link was replaced'
    assert_count 1 "clone $SKILLS_URL" "$GIT_LOG"
    assert_contains 'pull --ff-only' "$GIT_LOG"
    [[ $(find "$HOME_DIR/dotfiles-migration-backups" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ') == 1 ]] || fail 'repeat skills install created extra backups'
}

test_conflicting_skills_are_backed_up_and_unrelated_skills_preserved() {
    make_fixture
    mkdir -p "$HOME_DIR/.agents/skills/technical-writing" "$HOME_DIR/.agents/skills/unrelated"
    printf 'old skill\n' > "$HOME_DIR/.agents/skills/technical-writing/SKILL.md"
    printf 'unrelated skill\n' > "$HOME_DIR/.agents/skills/unrelated/SKILL.md"
    ln -s "$FIXTURE/missing-skill" "$HOME_DIR/.agents/skills/another-skill"
    ln -s "$FIXTURE/unrelated-target" "$HOME_DIR/.agents/skills/unrelated-link"
    mkdir -p "$HOME_DIR/.codex/skills/unrelated" "$HOME_DIR/.codex/skills/another-skill"
    printf 'Codex unrelated\n' > "$HOME_DIR/.codex/skills/unrelated/SKILL.md"
    printf 'Codex old skill\n' > "$HOME_DIR/.codex/skills/another-skill/SKILL.md"
    ln -s "$FIXTURE/wrong-target" "$HOME_DIR/.codex/skills/technical-writing"
    run_installer
    assert_contains 'old skill' "$(skill_backup_path .agents/skills/technical-writing)/SKILL.md"
    assert_symlink_to "$(skill_backup_path .agents/skills/another-skill)" "$FIXTURE/missing-skill"
    assert_contains 'unrelated skill' "$HOME_DIR/.agents/skills/unrelated/SKILL.md"
    assert_symlink_to "$HOME_DIR/.agents/skills/unrelated-link" "$FIXTURE/unrelated-target"
    assert_symlink_to "$HOME_DIR/.agents/skills/technical-writing" "$SKILLS_REPO/skills/technical-writing"
    assert_symlink_to "$(skill_backup_path .codex/skills/technical-writing)" "$FIXTURE/wrong-target"
    assert_contains 'Codex old skill' "$(skill_backup_path .codex/skills/another-skill)/SKILL.md"
    assert_contains 'Codex unrelated' "$HOME_DIR/.codex/skills/unrelated/SKILL.md"
    assert_symlink_to "$HOME_DIR/.codex/skills/technical-writing" "$SKILLS_REPO/skills/technical-writing"
    assert_contains 'conflicting' "$FIXTURE/output"
}

test_conflicting_skill_file_is_backed_up() {
    make_fixture
    mkdir -p "$HOME_DIR/.agents/skills"
    printf 'conflicting file\n' > "$HOME_DIR/.agents/skills/technical-writing"
    run_installer
    assert_contains 'conflicting file' "$(skill_backup_path .agents/skills/technical-writing)"
    assert_symlink_to "$HOME_DIR/.agents/skills/technical-writing" "$SKILLS_REPO/skills/technical-writing"
}

test_dirty_skills_checkout_is_preserved_without_update() {
    make_fixture
    clone_existing_skills
    printf 'local edit\n' >> "$SKILLS_REPO/skills/technical-writing/SKILL.md"
    "$REAL_GIT" -C "$SKILLS_REPO" add .
    printf 'unstaged edit\n' >> "$SKILLS_REPO/skills/another-skill/SKILL.md"
    printf 'untracked\n' > "$SKILLS_REPO/local.txt"
    local before after
    before=$("$REAL_GIT" -C "$SKILLS_REPO" status --porcelain)
    advance_skills_remote
    run_installer
    after=$("$REAL_GIT" -C "$SKILLS_REPO" status --porcelain)
    [[ "$before" == "$after" ]] || fail 'local Git state changed'
    assert_contains 'local edit' "$SKILLS_REPO/skills/technical-writing/SKILL.md"
    assert_contains 'unstaged edit' "$SKILLS_REPO/skills/another-skill/SKILL.md"
    assert_contains 'untracked' "$SKILLS_REPO/local.txt"
    assert_count 0 'pull' "$GIT_LOG"
    assert_count 0 'fetch' "$GIT_LOG"
    assert_contains 'local changes' "$FIXTURE/output"
    assert_symlink_to "$HOME_DIR/.agents/skills/technical-writing" "$SKILLS_REPO/skills/technical-writing"
}

test_clean_skills_checkout_fast_forwards() {
    make_fixture
    clone_existing_skills
    advance_skills_remote
    run_installer
    assert_contains 'upstream addition' "$SKILLS_REPO/skills/another-skill/SKILL.md"
    assert_contains 'pull --ff-only' "$GIT_LOG"
}

test_divergent_skills_checkout_is_not_reset() {
    make_fixture
    clone_existing_skills
    printf 'local commit\n' > "$SKILLS_REPO/local.txt"
    "$REAL_GIT" -C "$SKILLS_REPO" add .
    "$REAL_GIT" -C "$SKILLS_REPO" commit -qm local
    local before
    before=$("$REAL_GIT" -C "$SKILLS_REPO" rev-parse HEAD)
    advance_skills_remote
    expect_install_failure
    [[ $("$REAL_GIT" -C "$SKILLS_REPO" rev-parse HEAD) == "$before" ]] || fail 'divergent local commit changed'
    assert_contains 'local commit' "$SKILLS_REPO/local.txt"
    assert_file_absent "$HOME_DIR/.agents/skills/technical-writing"
}

test_unavailable_github_access_explains_authentication() {
    make_fixture
    DENY_ACCESS=1
    mkdir -p "$HOME_DIR/.codex/skills/write-like-roger"
    printf 'legacy skill\n' > "$HOME_DIR/.codex/skills/write-like-roger/SKILL.md"
    expect_install_failure
    assert_contains 'gh auth login' "$FIXTURE/output"
    assert_contains 'gh auth status' "$FIXTURE/output"
    assert_contains './install-macos.sh' "$FIXTURE/output"
    assert_file_absent "$SKILLS_REPO"
    assert_file_absent "$HOME_DIR/.agents/skills/technical-writing"
    assert_contains 'legacy skill' "$HOME_DIR/.codex/skills/write-like-roger/SKILL.md"
}

test_existing_checkout_still_requires_github_access() {
    make_fixture
    clone_existing_skills
    DENY_ACCESS=1
    expect_install_failure
    assert_file_absent "$HOME_DIR/.agents/skills/technical-writing"
}

test_legacy_skill_is_retired_after_new_link() {
    make_fixture
    mkdir -p "$HOME_DIR/.codex/skills/write-like-roger" "$HOME_DIR/.codex/retired-skills/write-like-roger"
    printf 'active legacy\n' > "$HOME_DIR/.codex/skills/write-like-roger/SKILL.md"
    printf 'already retired\n' > "$HOME_DIR/.codex/retired-skills/write-like-roger/SKILL.md"
    run_installer
    assert_symlink_to "$HOME_DIR/.agents/skills/technical-writing" "$SKILLS_REPO/skills/technical-writing"
    assert_file_exists "$HOME_DIR/.agents/skills/technical-writing/SKILL.md"
    assert_file_absent "$HOME_DIR/.codex/skills/write-like-roger"
    assert_contains 'active legacy' "$(skill_backup_path .codex/skills/write-like-roger)/SKILL.md"
    assert_contains 'already retired' "$HOME_DIR/.codex/retired-skills/write-like-roger/SKILL.md"
}

test_missing_technical_writing_does_not_retire_legacy_skill() {
    make_fixture
    clone_existing_skills
    rm "$SKILLS_REPO/skills/technical-writing/SKILL.md"
    mkdir -p "$HOME_DIR/.codex/skills/write-like-roger"
    printf 'legacy skill\n' > "$HOME_DIR/.codex/skills/write-like-roger/SKILL.md"
    expect_install_failure
    assert_contains 'legacy skill' "$HOME_DIR/.codex/skills/write-like-roger/SKILL.md"
}

test_no_migrate_preserves_legacy_skill() {
    make_fixture
    mkdir -p "$HOME_DIR/.codex/skills/write-like-roger"
    run_installer --no-migrate
    assert_file_exists "$HOME_DIR/.codex/skills/write-like-roger"
    assert_symlink_to "$HOME_DIR/.agents/skills/technical-writing" "$SKILLS_REPO/skills/technical-writing"
}

test_dry_run_fresh_skills_does_not_invoke_git() {
    make_fixture
    DENY_ACCESS=1
    run_installer --dry-run
    assert_file_absent "$SKILLS_REPO"
    assert_file_absent "$HOME_DIR/.agents"
    [[ ! -s "$GIT_LOG" ]] || fail 'fresh dry-run invoked Git'
    assert_contains "$SKILLS_URL" "$FIXTURE/output"
    assert_contains "$HOME_DIR/.agents/skills" "$FIXTURE/output"
}

test_dry_run_existing_skills_preserves_conflicts_and_repository() {
    make_fixture
    clone_existing_skills
    advance_skills_remote
    DENY_ACCESS=1
    mkdir -p "$HOME_DIR/.agents/skills/technical-writing" "$HOME_DIR/.codex/skills/write-like-roger"
    printf 'keep me\n' > "$HOME_DIR/.agents/skills/technical-writing/SKILL.md"
    touch -t 202501010101 "$SKILLS_REPO/skills/technical-writing/SKILL.md"
    local before index_before
    before=$("$REAL_GIT" -C "$SKILLS_REPO" rev-parse HEAD)
    index_before=$(cksum "$SKILLS_REPO/.git/index")
    run_installer --dry-run
    [[ $("$REAL_GIT" -C "$SKILLS_REPO" rev-parse HEAD) == "$before" ]] || fail 'dry-run updated repository'
    [[ $(cksum "$SKILLS_REPO/.git/index") == "$index_before" ]] || fail 'dry-run rewrote the Git index'
    assert_contains 'keep me' "$HOME_DIR/.agents/skills/technical-writing/SKILL.md"
    assert_file_exists "$HOME_DIR/.codex/skills/write-like-roger"
    assert_file_absent "$HOME_DIR/dotfiles-migration-backups"
    assert_count 0 'ls-remote' "$GIT_LOG"
    assert_count 0 'pull' "$GIT_LOG"
    assert_contains 'would link' "$FIXTURE/output"
    assert_contains 'would back up' "$FIXTURE/output"
}

test_non_repository_at_checkout_path_is_preserved() {
    make_fixture
    mkdir -p "$SKILLS_REPO"
    printf 'keep me\n' > "$SKILLS_REPO/local.txt"
    expect_install_failure
    assert_contains 'keep me' "$SKILLS_REPO/local.txt"
    assert_count 0 'clone' "$GIT_LOG"
}

test_wrong_repository_origin_is_preserved() {
    make_fixture
    clone_existing_skills
    "$REAL_GIT" -C "$SKILLS_REPO" remote set-url origin https://github.com/example/unrelated.git
    expect_install_failure
    assert_count 0 'pull' "$GIT_LOG"
    [[ $("$REAL_GIT" -C "$SKILLS_REPO" remote get-url origin) == https://github.com/example/unrelated.git ]] || fail 'unrelated origin changed'
}

test_homelab_conflicts_are_reported_and_backed_up() {
    make_fixture
    mkdir -p "$HOME_DIR/.agents/skills" "$HOME_DIR/.codex/skills/homelab-admin"
    ln -s "$FIXTURE/old-homelab" "$HOME_DIR/.agents/skills/homelab-admin"
    printf 'old homelab\n' > "$HOME_DIR/.codex/skills/homelab-admin/SKILL.md"
    run_installer
    assert_symlink_to "$(skill_backup_path .agents/skills/homelab-admin)" "$FIXTURE/old-homelab"
    assert_contains 'old homelab' "$(skill_backup_path .codex/skills/homelab-admin)/SKILL.md"
    assert_symlink_to "$HOME_DIR/.agents/skills/homelab-admin" "$HOMELAB_SKILL"
    assert_symlink_to "$HOME_DIR/.codex/skills/homelab-admin" "$HOMELAB_SKILL"
    assert_contains 'conflicting' "$FIXTURE/output"
}

test_missing_homelab_source_is_reported_and_installed_skill_preserved() {
    make_fixture
    rm -rf "$HOMELAB_SKILL"
    mkdir -p "$HOME_DIR/.codex/skills/homelab-admin"
    printf 'existing homelab\n' > "$HOME_DIR/.codex/skills/homelab-admin/SKILL.md"
    run_installer
    assert_contains 'WARNING:' "$FIXTURE/output"
    assert_contains "$HOMELAB_SKILL" "$FIXTURE/output"
    assert_contains 'existing homelab' "$HOME_DIR/.codex/skills/homelab-admin/SKILL.md"
    assert_file_absent "$HOME_DIR/.agents/skills/homelab-admin"
}

test_homelab_directory_without_skill_manifest_is_reported() {
    make_fixture
    rm "$HOMELAB_SKILL/SKILL.md"
    run_installer
    assert_contains 'WARNING:' "$FIXTURE/output"
    assert_contains "$HOMELAB_SKILL/SKILL.md" "$FIXTURE/output"
    assert_file_absent "$HOME_DIR/.agents/skills/homelab-admin"
    assert_file_absent "$HOME_DIR/.codex/skills/homelab-admin"
}

test_github_credentials_do_not_depend_on_replaced_gitconfig() {
    make_fixture
    run_installer
    assert_contains 'credential.https://github.com.helper=' "$GIT_LOG"
    assert_contains "$BIN/gh auth git-credential" "$GIT_LOG"
    assert_symlink_to "$HOME_DIR/.gitconfig" "$SCRIPT_DIR/config/gitconfig"
}

for test in \
    test_fresh_skills_installation \
    test_repeat_skills_installation_keeps_links \
    test_conflicting_skills_are_backed_up_and_unrelated_skills_preserved \
    test_conflicting_skill_file_is_backed_up \
    test_dirty_skills_checkout_is_preserved_without_update \
    test_clean_skills_checkout_fast_forwards \
    test_divergent_skills_checkout_is_not_reset \
    test_unavailable_github_access_explains_authentication \
    test_existing_checkout_still_requires_github_access \
    test_legacy_skill_is_retired_after_new_link \
    test_missing_technical_writing_does_not_retire_legacy_skill \
    test_no_migrate_preserves_legacy_skill \
    test_dry_run_fresh_skills_does_not_invoke_git \
    test_dry_run_existing_skills_preserves_conflicts_and_repository \
    test_non_repository_at_checkout_path_is_preserved \
    test_wrong_repository_origin_is_preserved \
    test_homelab_conflicts_are_reported_and_backed_up \
    test_missing_homelab_source_is_reported_and_installed_skill_preserved \
    test_homelab_directory_without_skill_manifest_is_reported \
    test_github_credentials_do_not_depend_on_replaced_gitconfig \
    test_dry_run_does_not_mutate \
    test_mode_requires_explicit_brew \
    test_first_install_backs_up_legacy_links_and_preserves_unrelated_files \
    test_second_install_is_idempotent \
    test_no_migrate_leaves_private_and_oh_my_zsh_untouched \
    test_unmanaged_files_are_backed_up_before_replacement; do
    if (($#)) && [[ "$test" != "$1" ]]; then
        continue
    fi
    "$test"
    printf 'PASS: %s\n' "$test"
    rm -rf "$FIXTURE"
done
printf 'PASS: macOS installer tests\n'
