# Repeatable macOS Setup Design

## Goal

Replace the 2017 dotfile linker with a repeatable macOS setup that can provision a new Mac, migrate the current Mac safely, and converge on the same user configuration when rerun.

## Architecture

The repository will provide one user-facing entry point, `install-macos.sh`, with three explicit phases: Homebrew provisioning, configuration installation, and legacy migration. Each phase will be idempotent and independently testable. The default run will install missing declared tools and link configuration; it will not upgrade or uninstall unrelated software.

Homebrew will own command-line and application installation through a committed `Brewfile`. The installer will detect both Intel and Apple Silicon Homebrew locations, initialise Homebrew’s environment for the current process, and use `brew bundle check` before installing missing dependencies. The Brewfile will contain the essential terminal and development tools already used by Rog, including GitHub CLI, tmux, mosh, ripgrep, fzf, jq, fd, eza, direnv, shellcheck, Codex, OpenCode, and Ghostty.

The configuration layer will use plain Zsh instead of cloning or vendoring `oh-my-zsh`. `zprofile` will establish Homebrew and user paths; `zshrc` will contain small, portable shell functions and aliases; `gitconfig`, `gitignore_global`, `tmux.conf`, Vim, Bash, and Fish configuration will live under `config/`. Private values will remain outside Git and will be sourced from a user-local private file when present.

## Migration and cleanup

The installer will identify only the legacy top-level links created by the old repository: `.bashrc`, `.gitconfig`, `.gitignore_global`, `.oh-my-zsh`, `.private`, `.vimrc`, and `.zshrc`. Before replacing any existing path, it will move the path into a timestamped backup directory under `~/dotfiles-migration-backups/`. It will preserve the old repository and all unrelated files.

The migration will not remove Homebrew packages, `~/.config`, SSH keys, application state, language-version managers, caches, or credentials. A private file linked by the legacy setup will be copied into a user-local configuration location with its existing mode preserved, then sourced by the new shell configuration. The migration command will support dry-run output and will refuse to overwrite a non-managed path without creating a backup first.

## Repeatability

Running `./install-macos.sh` on a new Mac will install Homebrew if it is absent, install the declared Brewfile dependencies, create required user directories, and create or replace only the managed links. Running it again will report no configuration changes when the desired state is already present. A `--no-migrate` option will allow a clean new-Mac installation without legacy cleanup, while `--dry-run` will show all planned actions without changing the machine.

Authentication remains explicit. The installer may install `gh`, Codex, and OpenCode, but it will not run login flows or store API keys. The README will document the one-time commands for GitHub authentication and provider sign-in.

## Testing

The repository will add shell tests that run the installer against a temporary fake home and fake Homebrew commands. Tests will cover dry-run non-mutation, first install, repeat install, backup creation, legacy symlink migration, refusal to overwrite an unmanaged file, Intel and Apple Silicon Homebrew discovery, and preservation of unrelated configuration. Shell syntax checks and a macOS-only smoke-test command will be documented separately.

## Out of scope

The installer will not manage macOS system defaults, LaunchAgents, SSH keys, application-specific configuration under `~/.config`, Homebrew cleanup, or package version pinning. Those can be added later as separate, explicit profiles if they become necessary.
