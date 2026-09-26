# macOS setup

This repository contains Rog's repeatable macOS command-line setup. It installs declared Homebrew dependencies, links portable shell and tool configuration, and migrates the old dotfile links into a timestamped backup.

## New Mac

```sh
git clone git@github.com:rogernolan/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install-macos.sh --dry-run
./install-macos.sh
exec zsh
```

The installer is safe to rerun. It installs missing entries from `Brewfile` without upgrading or uninstalling unrelated packages. It does not authenticate GitHub, Codex, or OpenCode.

Read [docs/macos-setup.md](docs/macos-setup.md) for migration, authentication, rollback, and verification details.
