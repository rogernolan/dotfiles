# macOS setup operations

## What the installer manages

`install-macos.sh` manages Homebrew dependencies and these user configuration paths:

```text
~/.zprofile
~/.zshrc
~/.bashrc
~/.gitconfig
~/.gitignore_global
~/.tmux.conf
~/.vimrc
~/.config/fish/config.fish
```

The installer uses symlinks back to this checkout, so editing a tracked configuration file changes the next shell started from that checkout. Homebrew owns installed tools through `Brewfile`; the installer runs `brew bundle install --no-upgrade` only when `brew bundle check` reports missing dependencies.

The installer does not manage application state under `~/.config`, SSH keys, credentials, language-version managers, caches, macOS defaults, or LaunchAgents. It does not run authentication flows.

## New Mac

Install Git using the macOS developer tools if necessary, then run:

```sh
git clone git@github.com:rogernolan/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install-macos.sh --dry-run
./install-macos.sh
exec zsh
```

The installer detects Homebrew at `/opt/homebrew/bin/brew` or `/usr/local/bin/brew`. If neither exists, it runs the official Homebrew installer and then installs the declared dependencies. A new shell is required after installation so `zprofile` can initialise Homebrew’s environment.

## Existing Mac migration

Inspect the planned migration first:

```sh
cd ~/dotfiles
./install-macos.sh --dry-run
```

Run the migration after reviewing the output:

```sh
./install-macos.sh
exec zsh
```

The installer backs up each replaced path under:

```text
~/dotfiles-migration-backups/YYYYmmdd-HHMMSS/
```

The old `.private` file is copied to `~/.config/rog/private` when that destination does not already exist. The old `.private` and `.oh-my-zsh` links are then moved into the backup. The old repository checkout is not deleted.

Use `--no-migrate` when installing the managed configuration without copying the old private file or removing the legacy-only links:

```sh
./install-macos.sh --no-migrate
```

## Authentication

Complete account setup separately after the tools are installed:

```sh
gh auth login
codex
opencode
```

OpenCode provider setup happens inside its interface with `/connect`. Keep API keys and private shell values outside this repository. Put shell-compatible private exports in `~/.config/rog/private`; Fish-specific values belong in `~/.config/rog/private.fish`.

## Verification

Check the package manifest and core commands:

```sh
brew bundle check --no-upgrade --file ~/dotfiles/Brewfile
command -v gh tmux mosh codex opencode
git config --global --get core.excludesfile
tmux -f ~/.tmux.conf -L dotfiles-verification -C start-server
tmux -L dotfiles-verification kill-server
```

The repository test suite uses a fake home and fake Homebrew, so it does not modify the real Mac:

```sh
cd ~/dotfiles
bash -n install-macos.sh tests/test_install_macos.sh
bash tests/test_install_macos.sh
```

## Rollback

Find the backup directory from the installer output. To restore one file, move the managed link aside and move the backup back into place. For example:

```sh
mv ~/.zshrc ~/.zshrc.new
mv ~/dotfiles-migration-backups/YYYYmmdd-HHMMSS/.zshrc ~/.zshrc
```

Do not run `brew bundle cleanup` as part of routine setup. Package removal is intentionally a separate, reviewed action.
