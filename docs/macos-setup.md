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

The managed Zsh configuration enables case-insensitive Tab completion. Its prompt shows a green username, cyan current directory, Git branch (or commit when detached), and `✗` for tracked or untracked changes. New Macs receive these settings through the installed `~/.zshrc` link. Restart an existing shell with `exec zsh -l` to load changes.

Dotfiles owns skill installation. The private [rog-skills repository](https://github.com/rogernolan/rog-skills) owns shared skill content. The installer clones it into `~/Development/rog-skills`, or reuses the checkout at that path, and links each directory containing `skills/<name>/SKILL.md` into both `~/.agents/skills/<name>` and `~/.codex/skills/<name>`. It preserves unrelated installed skills and reports conflicting destinations before moving them into the existing backup directory.

The installer also links `homelab-admin` from `~/Development/tob-lxc-setup/skills/homelab-admin` into both discovery directories. Obtain or restore that checkout separately. If the source directory or `SKILL.md` is missing, the installer reports the path and preserves any installed `homelab-admin` copy. It does not clone or update `tob-lxc-setup`.

The installer does not manage application state under `~/.config`, SSH keys, credentials, language-version managers, caches, macOS defaults, or LaunchAgents. It does not run authentication flows.

## New Mac

Install Git using the macOS developer tools if necessary, then run:

```sh
git clone https://github.com/rogernolan/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install-macos.sh --dry-run
./install-macos.sh
exec zsh -l
```

The installer detects Homebrew at `/opt/homebrew/bin/brew` or `/usr/local/bin/brew`. If neither exists, it runs the official Homebrew installer and then installs the declared dependencies. Use a login shell after installation so `zprofile` can initialise Homebrew’s environment.

On an unauthenticated Mac, the first installation stops at the private repository access check after installing tools and configuration. Start the new login shell with `exec zsh -l`, complete the GitHub authentication steps below, then rerun `./install-macos.sh`. `--dry-run` previews skills installation without accessing GitHub; it cannot establish whether authentication will succeed.

## Existing Mac migration

Inspect the planned migration first:

```sh
cd ~/dotfiles
./install-macos.sh --dry-run
```

Run the migration after reviewing the output:

```sh
./install-macos.sh
exec zsh -l
```

The installer backs up each replaced path under:

```text
~/dotfiles-migration-backups/YYYYmmdd-HHMMSS/
```

The old `.private` file is copied to `~/.config/rog/private` when that destination does not already exist. The old `.private` and `.oh-my-zsh` links are then moved into the backup. The old repository checkout is not deleted.

After verifying that both new `technical-writing` links resolve to a `SKILL.md` in `rog-skills`, the installer moves any active `~/.codex/skills/write-like-roger` installation into the same backup directory. Backups remain outside both skill discovery directories. An existing `~/.codex/retired-skills/write-like-roger` copy is preserved.

Use `--no-migrate` to install configuration and skills while preserving the old private file, legacy-only links, and active `write-like-roger` installation:

```sh
./install-macos.sh --no-migrate
```

## Authentication

Complete GitHub authentication interactively after GitHub CLI is available and before rerunning skills installation:

```sh
gh auth login --hostname github.com --git-protocol https
gh auth status --hostname github.com
cd ~/dotfiles
./install-macos.sh --dry-run
./install-macos.sh
```

Use an account authorised to access `rogernolan/rog-skills`. The installer disables Git terminal prompts and checks private repository access on every normal run, including when a checkout already exists. Its Git commands use a command-specific GitHub CLI credential helper, so access does not depend on a helper in the managed `~/.gitconfig`. No `gh auth setup-git` step is needed. If access fails, the installer prints the login and rerun commands and leaves skill links and the legacy skill in place.

The installer preserves staged, unstaged, and untracked repository changes by skipping updates when the checkout is dirty. A clean checkout is updated with `git pull --ff-only --no-rebase`; a failed update stops skills installation without resetting or rebasing local commits. A non-repository path or an unexpected origin at `~/Development/rog-skills` produces an error and is preserved. Resolve access or branch history separately and rerun.

When a fresh dry run has no skills checkout, it reports the clone and linking plan; individual skill names become available after cloning. For an existing checkout, it previews each link, conflict backup, and eligible legacy retirement. Neither case fetches, pulls, clones, or writes files.

Complete other account setup separately after installation:

```sh
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

Check representative skill links:

```sh
readlink ~/.agents/skills/technical-writing
readlink ~/.codex/skills/technical-writing
readlink ~/.agents/skills/homelab-admin
readlink ~/.codex/skills/homelab-admin
```

The repository test suite uses temporary homes, fake Homebrew and GitHub commands, and a local Git remote. It covers fresh and repeated installation, conflicts, unrelated skills, local changes, fast-forward and divergent history, unavailable private access, legacy retirement, missing homelab sources, and dry runs without modifying the real Mac or contacting GitHub:

```sh
cd ~/dotfiles
bash -n install-macos.sh tests/test_install_macos.sh
bash tests/test_install_macos.sh
bash tests/test_zsh_prompt.sh
python3 tests/test_zsh_completion.py
shellcheck install-macos.sh tests/test_install_macos.sh
```

## Rollback

Find the backup directory from the installer output. To restore one file, move the managed link aside and move the backup back into place. For example:

```sh
mv ~/.zshrc ~/.zshrc.new
mv ~/dotfiles-migration-backups/YYYYmmdd-HHMMSS/.zshrc ~/.zshrc
```

Do not run `brew bundle cleanup` as part of routine setup. Package removal is intentionally a separate, reviewed action.
