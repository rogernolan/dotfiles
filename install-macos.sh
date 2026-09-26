#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
HOME_DIR=${DOTFILES_HOME:-$HOME}
BREW=${DOTFILES_BREW:-}
DRY_RUN=0
MIGRATE=1
BACKUP_RUN=

usage() {
    cat <<'EOF'
Usage: ./install-macos.sh [options]

Install Rog's macOS tools and configuration.

Options:
  --dry-run       Show planned changes without modifying the machine.
  --no-migrate    Install managed configuration without removing legacy-only links.
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
    backup_existing "$destination"
    if ((DRY_RUN)); then
        log "would link $destination to $source"
        return
    fi
    mkdir -p "$(dirname "$destination")"
    ln -s "$source" "$destination"
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
    if [[ -n "$BACKUP_RUN" && ! -d "$BACKUP_RUN" ]] && (( ! DRY_RUN )); then
        die "backup directory was not created: $BACKUP_RUN"
    fi
    log 'macOS setup complete'
    if [[ -n "$BACKUP_RUN" ]]; then
        log "legacy/configuration backup: $BACKUP_RUN"
    fi
}

main "$@"
