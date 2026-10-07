# macOS setup

This repository contains Rog's repeatable macOS command-line setup. It installs declared Homebrew dependencies, links shell and tool configuration and repository-owned skills, and moves replaced paths into a timestamped backup. Dotfiles owns installation; [rog-skills](https://github.com/rogernolan/rog-skills) owns the shared skill content.

## New Mac

Install Apple’s Command Line Tools if Git is not available:

```sh
xcode-select --install
```

Then clone the repository and preview the changes before installing them:

```sh
git clone https://github.com/rogernolan/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install-macos.sh --dry-run
./install-macos.sh
exec zsh -l
```

The installer installs tools and configuration before checking access to the private skills repository. If GitHub access fails, start a new shell as shown above so Homebrew's commands are available, authenticate interactively, then rerun:

```sh
cd ~/dotfiles
gh auth login --hostname github.com --git-protocol https
gh auth status --hostname github.com
./install-macos.sh --dry-run
./install-macos.sh
```

Use a GitHub account with access to `rogernolan/rog-skills`. The installer uses GitHub CLI's saved credentials for its Git commands; it never starts a login flow. It installs missing entries from `Brewfile` without upgrading or uninstalling unrelated packages.

The installer clones or reuses `~/Development/rog-skills` and links each `skills/<name>/SKILL.md` directory individually into both `~/.agents/skills/<name>` and `~/.codex/skills/<name>`. Clean checkouts receive fast-forward-only updates; checkouts with local changes are linked without updating. Correct links and unrelated skills are preserved; conflicts are reported and backed up outside skill discovery.

The installer also links `homelab-admin` from `~/Development/tob-lxc-setup/skills/homelab-admin` into both skill directories. Keep that source checkout available; a missing directory or `SKILL.md` produces a warning and preserves any installed copy.

## Later Macs and repeat installs

Keep the repository up to date, preview the changes, then rerun the installer:

```sh
cd ~/dotfiles
git pull --ff-only
./install-macos.sh --dry-run
./install-macos.sh
exec zsh -l
```

The installer links the shell and tool configuration from this checkout, so the
new files take effect in the next shell. Existing files are backed up before
the installer replaces them. It does not remove unrelated Homebrew packages.

GitHub authentication is required for private skills installation. After setup, authenticate the other services you use:

```sh
codex
opencode
```

Read [docs/macos-setup.md](docs/macos-setup.md) for migration, authentication, rollback, and verification details.
