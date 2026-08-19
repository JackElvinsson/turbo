# turbo CLI design

## Purpose

A personal, single-purpose CLI tool that scaffolds new projects from
the `laravel-template` GitHub repo. Installable on any Linux/WSL
machine via a `curl | bash` one-liner, so a new project can be spun up
from any machine in a couple of interactive prompts, with an option to
also create the GitHub repo and run the template's own `setup.sh`.

Out of scope for now (deliberately, per YAGNI):
- Multi-OS support (macOS/native Windows) - Linux/WSL only.
- Support for templates other than `laravel-template` - hardcoded for
  now; adding a second template later is a small, separate change.
- A polished TUI (gum, dialog, etc.) - plain bash prompts, matching
  `setup.sh`'s existing style.

## Distribution

Repo: `jackelvinsson/turbo`, using the same `develop` + `master`
branching convention as `laravel-template`: day-to-day work happens on
`develop`, and `master` is the stable branch that gets released.
Everything below that fetches from GitHub (the install one-liner, the
version check) points at `master` - only merged, released work ever
reaches machines running `turbo`.

Install/update command (same command for both):

```bash
curl -fsSL https://raw.githubusercontent.com/jackelvinsson/turbo/master/install.sh | bash
```

## File layout

```
turbo           # the CLI itself - single bash script, dispatches subcommands
install.sh      # installer/updater
README.md       # what it does, the install one-liner
```

## install.sh behavior

0. Preflight: verify `git` and `curl` are on `PATH`. Fail fast with a
   clear message if not (both are required - `curl` to fetch the
   script itself, `git` for the version check in step 4).
1. Download the `turbo` script from the repo's raw `master` branch to
   `~/.local/bin/turbo`, `chmod +x` it.
2. If `~/.local/bin` is not on `PATH`, print a warning telling the
   user to add it (do not attempt to modify shell rc files
   automatically).
3. If `~/.config/turbo/config` does **not** already exist (first
   install, not an update):
   - Prompt: `Projects directory [/home/jack/PhpstormProjects]:`
   - Accept the default on empty input, or use the typed override.
   - Write `PROJECTS_DIR=<path>` to `~/.config/turbo/config`.
   - If the config file already exists, skip this prompt entirely -
     re-running the install command to update must never clobber an
     existing config.
4. Record the current `master` commit hash into
   `~/.local/share/turbo/version`, via:
   ```bash
   git ls-remote https://github.com/jackelvinsson/turbo master | cut -f1
   ```

## Commands

### `turbo create`

The interactive project-creation wizard.

1. **Update check** (see below). Non-blocking.
2. **Preflight**: verify `git` and `curl` are on `PATH`. Fail fast
   with a clear message if not.
3. Read `PROJECTS_DIR` from `~/.config/turbo/config`. Fall back to
   `/home/jack/PhpstormProjects` if the config file is missing or the
   variable is unset (defensive - `install.sh` should always have
   created it).
4. Prompt: `Project name:` (free text, e.g. "My Cool App").
5. Validate/slugify the name using the same approach `setup.sh`
   already uses in the template repo: reject anything other than
   letters, numbers, and spaces; derive a kebab-case slug for the
   repo/directory name (e.g. "My Cool App" -> `my-cool-app`).
6. Abort with a clear error if `$PROJECTS_DIR/<slug>` already exists.
   Never overwrite.
7. Prompt: `Create a GitHub repo for this? [y/N]`
   - **Yes**:
     - Verify `gh` is installed and `gh auth status` succeeds. If
       either fails, abort with instructions to run `gh auth login`
       (or install `gh`). Do not silently fall back to a local-only
       clone - that would surprise a user who explicitly asked for a
       GitHub repo.
     - Prompt: `Private or public? [Private/public]` (default:
       private).
     - Run, with cwd set to `$PROJECTS_DIR`:
       ```bash
       gh repo create <slug> --template jackelvinsson/laravel-template \
         --private|--public --clone
       ```
       This creates the repo and clones it directly to
       `$PROJECTS_DIR/<slug>` in one step. `gh`/`git`'s own progress
       output (visible in a terminal) covers the "show clone
       progress" requirement - no custom progress bar needed.
   - **No**:
     ```bash
     git clone --progress https://github.com/jackelvinsson/laravel-template.git \
       $PROJECTS_DIR/<slug>
     ```
     `git`'s native `--progress` output renders live transfer
     percentage in a terminal.
8. Prompt: `Cloning complete. Run project setup now? [Y/n]`
   - **Yes**: `cd $PROJECTS_DIR/<slug> && ./setup.sh "<project name>"`
   - **No**: print the `cd` + `./setup.sh` command so the user can run
     it manually later, then exit successfully.

### `turbo update`

Re-downloads the `turbo` script to `~/.local/bin/turbo` and refreshes
`~/.local/share/turbo/version`. Equivalent to `install.sh`'s steps 1
and 4, skipping the config prompt (config already exists). In
practice this can literally re-invoke the install script logic.

### `turbo` / `turbo help`

Prints usage: lists `create` and `update` with one-line descriptions.
Any unrecognized subcommand also prints usage and exits non-zero.

## Update check (part of `turbo create`)

Before the wizard starts:

1. `git ls-remote https://github.com/jackelvinsson/turbo master | cut -f1`
   to get the latest commit hash on `master`.
2. Compare to the hash stored in `~/.local/share/turbo/version`.
3. If they differ: print
   `A new version of turbo is available. Run 'turbo update' to update.`
   then prompt `Continue anyway? [Y/n]` (default: yes - never force an
   update).
4. If the `git ls-remote` call itself fails (offline, DNS, etc.),
   skip the check silently. A network hiccup must never block
   `turbo create` from working.

## Error handling summary

- Missing `git`/`curl`: fail fast, before any prompts.
- `gh` missing/unauthenticated (GitHub-repo path only): fail fast with
  fix instructions.
- Target directory already exists: abort, never overwrite.
- Version-check network failure: skip silently, continue normally.
- Clone failure (bad network, wrong URL, etc.): let git's/gh's own
  error output surface naturally; turbo does not need to wrap it.

## Testing / verification

This is a personal bash tool with no test framework of its own.
Verification is manual, end-to-end, on this machine, covering:

- Fresh install via the `curl | bash` command.
- `turbo create` choosing the GitHub-repo path (private, then public).
- `turbo create` choosing the local-only clone path.
- `turbo create` declining to run `setup.sh`, then running it
  manually per the printed instructions.
- `turbo update` after a new commit lands on `master`, confirming the
  update-check prompt appears on the next `turbo create` beforehand
  and disappears after updating.
- Rejection paths: existing target directory, invalid project name,
  missing `gh` auth when GitHub-repo path is chosen.
