#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
HOME_DIR=${DOTFILES_HOME:-$HOME}
BREW=${DOTFILES_BREW:-}
DRY_RUN=0
MIGRATE=1
BACKUP_RUN=
SKILLS_URL=https://github.com/rogernolan/rog-skills.git

usage() {
    cat <<'EOF'
Usage: ./install-macos.sh [options]

Install Rog's macOS tools and configuration.

Options:
  --dry-run       Show planned changes without modifying the machine.
  --no-migrate    Install configuration and skills without retiring legacy paths.
  --help          Show this help.
EOF
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

log() {
    printf 'INFO: %s\n' "$*"
}

path_exists() {
    [[ -e "$1" || -L "$1" ]]
}

run() {
    if ((DRY_RUN)); then
        printf '+'
        printf ' %q' "$@"
        printf '\n'
        return 0
    fi
    "$@"
}

parse_args() {
    while (($#)); do
        case "$1" in
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --no-migrate)
                MIGRATE=0
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                die "unknown option: $1"
                ;;
        esac
    done
}

validate_platform() {
    if [[ ${DOTFILES_TEST_MODE:-0} == 1 ]]; then
        return
    fi
    [[ "$(uname -s)" == Darwin ]] || die 'this installer supports macOS only'
}

discover_brew() {
    if [[ ${DOTFILES_TEST_MODE:-0} == 1 ]]; then
        [[ -n "$BREW" ]] || die 'DOTFILES_BREW is required in test mode'
        [[ -x "$BREW" ]] || die "Homebrew executable is not usable: $BREW"
        return
    fi
    if [[ -n "$BREW" ]]; then
        [[ -x "$BREW" ]] || die "Homebrew executable is not usable: $BREW"
        return
    fi
    if BREW=$(command -v brew 2>/dev/null); then
        return
    fi
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "$candidate" ]]; then
            BREW=$candidate
            return
        fi
    done
}

install_homebrew() {
    discover_brew
    [[ -n "$BREW" ]] && return

    if ((DRY_RUN)); then
        log 'would install Homebrew from the official installer'
        return
    fi

    command -v curl >/dev/null 2>&1 || die 'curl is required to install Homebrew'
    log 'installing Homebrew from the official installer'
    curl --fail --silent --show-error --location https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | /bin/bash
    BREW=
    discover_brew
    [[ -n "$BREW" ]] || die 'Homebrew installation completed without a usable brew executable'
}

install_brew_bundle() {
    local brewfile="$SCRIPT_DIR/Brewfile"
    [[ -f "$brewfile" ]] || die "missing Brewfile: $brewfile"

    if ((DRY_RUN)); then
        log "would check Homebrew dependencies from $brewfile"
        log "would install missing Homebrew dependencies without upgrading existing packages"
        return
    fi

    if "$BREW" bundle check --file "$brewfile" --no-upgrade >/dev/null 2>&1; then
        log 'Homebrew dependencies are already satisfied'
    else
        log 'installing missing Homebrew dependencies'
        "$BREW" bundle install --file "$brewfile" --no-upgrade
    fi
}

ensure_backup_dir() {
    if [[ -n "$BACKUP_RUN" ]]; then
        return
    fi
    BACKUP_RUN="$HOME_DIR/dotfiles-migration-backups/$(date +%Y%m%d-%H%M%S)"
    local suffix=1
    while path_exists "$BACKUP_RUN"; do
        BACKUP_RUN="$HOME_DIR/dotfiles-migration-backups/$(date +%Y%m%d-%H%M%S)-$suffix"
        suffix=$((suffix + 1))
    done
    if ((DRY_RUN)); then
        log "would create backup directory $BACKUP_RUN"
    else
        mkdir -p "$BACKUP_RUN"
    fi
}

backup_existing() {
    local destination=$1 relative target
    if ! path_exists "$destination"; then
        return 0
    fi
    ensure_backup_dir
    relative=${destination#"$HOME_DIR"/}
    target="$BACKUP_RUN/$relative"
    if ((DRY_RUN)); then
        log "would back up $destination to $target"
        return
    fi
    mkdir -p "$(dirname "$target")"
    mv -- "$destination" "$target"
}

link_managed_file() {
    local source=$1 destination=$2
    if [[ -L "$destination" && "$(readlink "$destination")" == "$source" ]]; then
        log "keeping $destination"
        return
    fi
    if path_exists "$destination"; then
        log "conflicting destination $destination; backing up before replacement"
    fi
    backup_existing "$destination"
    if ((DRY_RUN)); then
        log "would link $destination to $source"
        return
    fi
    mkdir -p "$(dirname "$destination")"
    ln -s "$source" "$destination"
}

skills_git() {
    local gh_executable
    gh_executable=$(command -v gh 2>/dev/null) || gh_executable="$(dirname "$BREW")/gh"
    [[ -x "$gh_executable" ]] || die 'GitHub CLI is required for skills access; install Homebrew dependencies, authenticate with gh auth login, then rerun ./install-macos.sh'
    GIT_OPTIONAL_LOCKS=0 GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never GIT_SSH_COMMAND='ssh -oBatchMode=yes' \
        git -c credential.https://github.com.helper= \
        -c "credential.https://github.com.helper=!$(printf '%q' "$gh_executable") auth git-credential" "$@"
}

skills_access_failed() {
    die "cannot access $SKILLS_URL. Authenticate separately with 'gh auth login --hostname github.com --git-protocol https', check 'gh auth status --hostname github.com' and confirm the account has repository access, then rerun ./install-macos.sh."
}

prepare_skills_checkout() {
    local repository=$1 root origin changes
    if path_exists "$repository"; then
        root=$(skills_git -C "$repository" rev-parse --show-toplevel 2>/dev/null) || die "skills source is not a Git checkout: $repository; preserving it"
        [[ "$root" == "$(cd -- "$repository" && pwd -P)" ]] || die "skills source is not the checkout root: $repository; preserving it"
        origin=$(skills_git -C "$repository" config --get remote.origin.url) || die "skills checkout has no origin: $repository; preserving it"
        case "$origin" in
            https://github.com/rogernolan/rog-skills|https://github.com/rogernolan/rog-skills.git|git@github.com:rogernolan/rog-skills|git@github.com:rogernolan/rog-skills.git|ssh://git@github.com/rogernolan/rog-skills|ssh://git@github.com/rogernolan/rog-skills.git) ;;
            *) die "skills checkout origin is not rogernolan/rog-skills: $repository; preserving it" ;;
        esac
    fi

    if ((DRY_RUN)); then
        log "would verify authenticated access to $SKILLS_URL without prompting"
    else
        command -v git >/dev/null 2>&1 || die 'Git is required to install skills; install Apple Command Line Tools and rerun ./install-macos.sh'
        skills_git ls-remote --exit-code "$SKILLS_URL" HEAD >/dev/null || skills_access_failed
    fi

    if ! path_exists "$repository"; then
        run mkdir -p "$(dirname "$repository")"
        if ((DRY_RUN)); then
            log "would clone $SKILLS_URL into $repository"
        else
            skills_git clone "$SKILLS_URL" "$repository" || skills_access_failed
        fi
        return
    fi

    changes=$(skills_git -C "$repository" status --porcelain --untracked-files=all) || die "cannot inspect local changes in $repository; preserving it"
    if [[ -n "$changes" ]]; then
        log "keeping skills checkout with local changes: $repository; skipping update"
    elif ((DRY_RUN)); then
        log "would update $repository with git pull --ff-only --no-rebase"
    else
        log "updating skills checkout with fast-forward only: $repository"
        skills_git -C "$repository" pull --ff-only --no-rebase || die "could not fast-forward $repository. Local commits are preserved; check repository access and branch history separately, then rerun ./install-macos.sh."
    fi
}

link_skill() {
    local source=$1 name=$2 discovery
    for discovery in "$HOME_DIR/.agents/skills" "$HOME_DIR/.codex/skills"; do
        link_managed_file "$source" "$discovery/$name"
    done
}

install_repository_skills() {
    local repository="$HOME_DIR/Development/rog-skills" manifest source name discovery
    prepare_skills_checkout "$repository"
    if ((DRY_RUN)) && [[ ! -d "$repository" ]]; then
        log "would link each directory containing $repository/skills/<name>/SKILL.md into $HOME_DIR/.agents/skills/<name> and $HOME_DIR/.codex/skills/<name>"
        if ((MIGRATE)) && path_exists "$HOME_DIR/.codex/skills/write-like-roger"; then
            log 'would verify the new technical-writing links before retiring write-like-roger'
            backup_existing "$HOME_DIR/.codex/skills/write-like-roger"
        fi
        return
    fi

    [[ -d "$repository/skills" ]] || die "missing skills source directory: $repository/skills"
    [[ -f "$repository/skills/technical-writing/SKILL.md" ]] || die "missing required skill source: $repository/skills/technical-writing/SKILL.md; keeping legacy write-like-roger"
    for manifest in "$repository"/skills/*/SKILL.md; do
        [[ -f "$manifest" ]] || continue
        source=${manifest%/SKILL.md}
        name=${source##*/}
        link_skill "$source" "$name"
    done

    if (( ! DRY_RUN )); then
        for discovery in "$HOME_DIR/.agents/skills" "$HOME_DIR/.codex/skills"; do
            [[ -L "$discovery/technical-writing" && "$(readlink "$discovery/technical-writing")" == "$repository/skills/technical-writing" && -f "$discovery/technical-writing/SKILL.md" ]] || die "technical-writing link verification failed: $discovery/technical-writing; keeping legacy write-like-roger"
        done
    fi
    if ((MIGRATE)); then
        backup_existing "$HOME_DIR/.codex/skills/write-like-roger"
    fi
}

install_homelab_skill() {
    local source="$HOME_DIR/Development/tob-lxc-setup/skills/homelab-admin"
    if [[ ! -d "$source" ]]; then
        log "WARNING: missing skill source directory $source; keeping installed homelab-admin. Restore the tob-lxc-setup checkout and rerun ./install-macos.sh."
        return
    fi
    if [[ ! -f "$source/SKILL.md" ]]; then
        log "WARNING: missing skill manifest $source/SKILL.md; keeping installed homelab-admin. Restore the source and rerun ./install-macos.sh."
        return
    fi
    link_skill "$source" homelab-admin
}

migrate_private_file() {
    local legacy="$HOME_DIR/.private" destination="$HOME_DIR/.config/rog/private"
    if ! path_exists "$legacy"; then
        return 0
    fi
    [[ -e "$legacy" ]] || {
        log "skipping broken legacy private link $legacy"
        return 0
    }
    if path_exists "$destination"; then
        log "keeping existing private file $destination"
        return
    fi
    if ((DRY_RUN)); then
        log "would copy legacy private file to $destination"
        return
    fi
    mkdir -p "$(dirname "$destination")"
    cp -p "$legacy" "$destination"
}

migrate_legacy_only_paths() {
    ((MIGRATE)) || return 0
    migrate_private_file
    backup_existing "$HOME_DIR/.private"
    backup_existing "$HOME_DIR/.oh-my-zsh"
}

install_configuration() {
    link_managed_file "$SCRIPT_DIR/config/zprofile" "$HOME_DIR/.zprofile"
    link_managed_file "$SCRIPT_DIR/config/zshrc" "$HOME_DIR/.zshrc"
    link_managed_file "$SCRIPT_DIR/config/bashrc" "$HOME_DIR/.bashrc"
    link_managed_file "$SCRIPT_DIR/config/gitconfig" "$HOME_DIR/.gitconfig"
    link_managed_file "$SCRIPT_DIR/config/gitignore_global" "$HOME_DIR/.gitignore_global"
    link_managed_file "$SCRIPT_DIR/config/tmux.conf" "$HOME_DIR/.tmux.conf"
    link_managed_file "$SCRIPT_DIR/config/vimrc" "$HOME_DIR/.vimrc"
    link_managed_file "$SCRIPT_DIR/config/fish/config.fish" "$HOME_DIR/.config/fish/config.fish"
}

main() {
    parse_args "$@"
    validate_platform
    install_homebrew
    install_brew_bundle
    migrate_legacy_only_paths
    install_configuration
    install_repository_skills
    install_homelab_skill
    if [[ -n "$BACKUP_RUN" && ! -d "$BACKUP_RUN" ]] && (( ! DRY_RUN )); then
        die "backup directory was not created: $BACKUP_RUN"
    fi
    log 'macOS setup complete'
    if [[ -n "$BACKUP_RUN" ]]; then
        log "legacy/configuration/skills backup: $BACKUP_RUN"
    fi
}

main "$@"
