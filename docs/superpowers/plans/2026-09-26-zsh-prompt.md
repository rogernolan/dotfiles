# Git-aware zsh Prompt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the compact `username:folder (branch status)` prompt without depending on Oh My Zsh.

**Architecture:** `config/zshrc` will define one small prompt helper that reports the current Git ref and a single `✗` when the worktree is dirty. The prompt will use zsh-native colour escapes for the username, directory, and prompt character, while remaining empty of Git text outside repositories.

**Tech Stack:** zsh, Git, Bash integration tests.

## Global Constraints

- Do not add an Oh My Zsh or third-party prompt dependency.
- Treat tracked changes, staged changes, and untracked files as dirty.
- Keep prompt evaluation safe outside Git repositories and in detached HEAD state.

---

### Task 1: Add the Git-aware prompt

**Files:**
- Modify: `config/zshrc`
- Create: `tests/test_zsh_prompt.sh`

**Interfaces:**
- Produces `dotfiles_git_prompt`, a zsh function that prints either an empty string or ` (ref)` / ` (ref ✗)`.

- [x] **Step 1: Write focused prompt tests**

The test will create temporary Git repositories and invoke the helper through a clean zsh process. It will assert empty output outside Git, clean branch output, dirty output, untracked output, and detached-HEAD output.

- [x] **Step 2: Run the prompt tests and verify they fail**

Run: `bash tests/test_zsh_prompt.sh`

Expected: FAIL because `dotfiles_git_prompt` is not defined.

- [x] **Step 3: Implement the minimal prompt helper and coloured prompt**

Add `autoload -Uz colors; colors`, define `dotfiles_git_prompt`, enable `prompt_subst`, and set `PROMPT` to colour the username, current directory, Git segment, and `%#` prompt character.

- [x] **Step 4: Run syntax and behaviour checks**

Run:

```sh
bash -n tests/test_zsh_prompt.sh
bash tests/test_zsh_prompt.sh
zsh -n config/zshrc
```

Expected: all checks pass.

- [x] **Step 5: Commit the prompt change**

```sh
git add config/zshrc tests/test_zsh_prompt.sh docs/superpowers/plans/2026-09-26-zsh-prompt.md
git commit -m "feat: restore git-aware zsh prompt"
```
