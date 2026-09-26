# Repeatable macOS Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a safe, repeatable macOS bootstrap that installs declared tools, links portable configuration, and migrates the old dotfile links into timestamped backups.

**Architecture:** `install-macos.sh` owns orchestration and delegates package installation to Homebrew Bundle and file convergence to a small link/backup layer. The installer accepts dry-run and test seams, never authenticates services, and only removes the explicitly identified legacy dotfile links. Shell integration tests run against a temporary home and fake Homebrew.

**Tech Stack:** Bash, Homebrew Bundle, Zsh, Git, tmux, Vim, Fish, shell integration tests.

## Global Constraints

- Support Apple Silicon and Intel Homebrew locations: `/opt/homebrew/bin/brew` and `/usr/local/bin/brew`.
- Default runs install missing Brewfile dependencies with `--no-upgrade`; they do not uninstall packages.
- Default runs back up any replaced path under `~/dotfiles-migration-backups/<timestamp>/`.
- Preserve `~/.config`, SSH keys, application state, caches, credentials, and unrelated files.
- Do not run `gh auth login`, Codex sign-in, OpenCode provider setup, or write credentials.
- Use `DOTFILES_HOME`, `DOTFILES_BREW`, and `DOTFILES_TEST_MODE` only as test seams; normal runs use the real home and Homebrew.
- Keep existing unrelated `.DS_Store` changes out of implementation commits.

---

### Task 1: Add failing installer integration tests

**Files:**
- Create: `tests/test_install_macos.sh`

**Interfaces:**
- Consumes: future `install-macos.sh` options `--dry-run` and `--no-migrate`, plus `DOTFILES_HOME`, `DOTFILES_BREW`, and `DOTFILES_TEST_MODE`.
- Produces: executable integration tests covering the desired filesystem and Homebrew behavior.

- [ ] **Step 1: Write the failing tests**

Create a fake Homebrew executable that records `bundle check` and `bundle install` calls. Add tests for:

```bash
test_dry_run_does_not_mutate
test_first_install_backs_up_legacy_links_and_preserves_unrelated_files
test_second_install_is_idempotent
test_no_migrate_leaves_private_and_oh_my_zsh_untouched
test_unmanaged_files_are_backed_up_before_replacement
```

Each test creates a temporary home, invokes `install-macos.sh` with `DOTFILES_TEST_MODE=1`, and asserts symlink targets, backup contents, private-file preservation, Homebrew calls, and unrelated-file preservation.

- [ ] **Step 2: Run the tests and verify the expected failure**

Run:

```bash
bash tests/test_install_macos.sh
```

Expected result: failure because `install-macos.sh` does not exist.

### Task 2: Add the package manifest and installer skeleton

**Files:**
- Create: `Brewfile`
- Create: `install-macos.sh`

**Interfaces:**
- Consumes: `Brewfile`, command-line options, and the environment seams from Task 1.
- Produces: `install-macos.sh --dry-run`, `install-macos.sh --no-migrate`, and a repeatable Homebrew provisioning phase.

- [ ] **Step 1: Add the declared package manifest**

Add formula entries for `bat`, `direnv`, `eza`, `fd`, `fzf`, `gh`, `jq`, `mosh`, `ripgrep`, `rtk`, `shellcheck`, and `tmux`; add `cask "codex"`, `tap "anomalyco/tap"`, `brew "anomalyco/tap/opencode"`, and `cask "ghostty"`. Keep package comments limited to why a package is required.

- [ ] **Step 2: Implement argument parsing and preflight**

Implement strict Bash mode, repository-root discovery, `--dry-run`, `--no-migrate`, usage output, macOS validation, and Homebrew discovery in this order:

```text
DOTFILES_BREW -> command -v brew -> /opt/homebrew/bin/brew -> /usr/local/bin/brew
```

When Homebrew is absent, normal mode may run the official Homebrew installer through `curl` and `/bin/bash`; dry-run mode must only print the planned action. Test mode must fail clearly unless `DOTFILES_BREW` supplies a fake executable.

- [ ] **Step 3: Implement Homebrew Bundle convergence**

Run `brew bundle check --file <repo>/Brewfile`. If it reports missing dependencies, run `brew bundle install --file <repo>/Brewfile --no-upgrade`. Do not call `brew bundle cleanup` or `brew upgrade`.

- [ ] **Step 4: Run the Task 1 tests**

Run:

```bash
bash tests/test_install_macos.sh
```

Expected result: package-manifest and preflight assertions pass; link and migration assertions still fail until Task 3 and Task 4 are implemented.

### Task 3: Add managed configuration and safe linking

**Files:**
- Create: `config/zprofile`
- Create: `config/zshrc`
- Create: `config/bashrc`
- Create: `config/fish/config.fish`
- Create: `config/gitconfig`
- Create: `config/gitignore_global`
- Create: `config/tmux.conf`
- Create: `config/vimrc`
- Modify: `install-macos.sh`

**Interfaces:**
- Consumes: destination paths under `DOTFILES_HOME`.
- Produces: managed links for `.zprofile`, `.zshrc`, `.bashrc`, `.gitconfig`, `.gitignore_global`, `.tmux.conf`, `.vimrc`, and `.config/fish/config.fish`.

- [ ] **Step 1: Add the portable configuration files**

Use plain Zsh with Homebrew path initialisation, standard Git aliases, an optional private-file source at `$HOME/.config/rog/private`, and no `oh-my-zsh` dependency. Use XDG-aware paths and avoid absolute user names. Add a minimal tmux configuration and retain only useful Vim settings.

- [ ] **Step 2: Add the link manager**

Implement `link_managed_file(source, destination)` with these rules:

```text
destination -> correct source: no-op
destination exists or is a symlink: move it to the current backup directory
destination absent: create parent directory and symlink
```

Create the backup directory lazily so an idempotent run does not create empty backup directories. In dry-run mode, print each move and link without changing files.

- [ ] **Step 3: Run focused tests**

Run:

```bash
bash tests/test_install_macos.sh
```

Expected result: managed-link, repeatability, dry-run, and unrelated-file assertions pass; private migration assertions remain until Task 4.

### Task 4: Add legacy migration and cleanup

**Files:**
- Modify: `install-macos.sh`
- Modify: `tests/test_install_macos.sh`

**Interfaces:**
- Consumes: legacy paths `.bashrc`, `.gitconfig`, `.gitignore_global`, `.oh-my-zsh`, `.private`, `.vimrc`, and `.zshrc`.
- Produces: timestamped backups under `.dotfiles-migration-backups`, optional private-file copy under `.config/rog/private`, and no mutation outside the approved boundary.

- [ ] **Step 1: Write the private migration regression test**

Assert that a legacy `.private` symlink is copied to `.config/rog/private` with its mode preserved, while `.config/opencode` and `.ssh` remain byte-for-byte unchanged.

- [ ] **Step 2: Implement migration**

Before replacing managed links, copy a readable legacy private target only when the new private destination is absent. Back up the legacy `.private` and `.oh-my-zsh` paths, then remove their active links. If `--no-migrate` is supplied, skip private migration and legacy-only cleanup while still installing the new managed configuration.

- [ ] **Step 3: Add refusal and backup checks**

Ensure every existing managed destination is moved into the backup directory before replacement. Preserve symlinks as symlinks in the backup. Never recursively delete the old repository or any unrelated directory.

- [ ] **Step 4: Run the full integration tests**

Run:

```bash
bash tests/test_install_macos.sh
```

Expected result: all tests pass, including first install, repeat install, dry-run, private migration, and unrelated-state preservation.

### Task 5: Update documentation and verification

**Files:**
- Replace: `README.markdown`
- Create: `docs/macos-setup.md`

**Interfaces:**
- Consumes: the final installer options and Brewfile.
- Produces: new-Mac and existing-Mac procedures, authentication guidance, rollback instructions, and verification commands.

- [ ] **Step 1: Document the new-Mac flow**

Document cloning the repository, running `./install-macos.sh`, opening a new shell, checking `brew bundle check`, and completing optional `gh`, Codex, and OpenCode authentication manually.

- [ ] **Step 2: Document the existing-Mac migration flow**

Document `./install-macos.sh --dry-run`, the normal migration, the backup directory, and how to restore a specific legacy link from the timestamped backup.

- [ ] **Step 3: Run syntax and test verification**

Run:

```bash
bash -n install-macos.sh tests/test_install_macos.sh
bash tests/test_install_macos.sh
git diff --check
```

Expected result: all commands exit zero and the test script reports `PASS` for every case. A real Mac smoke test will verify Homebrew Bundle and command availability after installation.
