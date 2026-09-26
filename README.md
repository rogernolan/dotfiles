# macOS setup

This repository contains Rog's repeatable macOS command-line setup. It installs declared Homebrew dependencies, links portable shell and tool configuration, and migrates the old dotfile links into a timestamped backup.

## New Mac

Install Apple’s Command Line Tools if Git is not available:

```sh
xcode-select --install
```

Then clone the repository and preview the changes before installing them:

```sh
git clone git@github.com:rogernolan/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install-macos.sh --dry-run
./install-macos.sh
exec zsh
```

The installer is safe to rerun. It installs missing entries from `Brewfile` without upgrading or uninstalling unrelated packages. It does not authenticate GitHub, Codex, or OpenCode.

## Later Macs and repeat installs

Keep the repository up to date, preview the changes, then rerun the installer:

```sh
cd ~/dotfiles
git pull --ff-only
./install-macos.sh --dry-run
./install-macos.sh
exec zsh
```

The installer links the shell and tool configuration from this checkout, so the
new files take effect in the next shell. Existing files are backed up before
the installer replaces them. It does not remove unrelated Homebrew packages.

After the tools are installed, authenticate the services you use:

```sh
gh auth login
codex
opencode
```

Read [docs/macos-setup.md](docs/macos-setup.md) for migration, authentication, rollback, and verification details.
