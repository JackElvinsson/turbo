```
 ______   __  __     ______     ______     ______
/\__  _\ /\ \/\ \   /\  == \   /\  == \   /\  __ \
\/_/\ \/ \ \ \_\ \  \ \  __<   \ \  __<   \ \ \/\ \
   \ \_\  \ \_____\  \ \_\ \_\  \ \_____\  \ \_____\
    \/_/   \/_____/   \/_/ /_/   \/_____/   \/_____/ v1.2.0 - Scaffold Laravel projects, fast.
```

A personal CLI that scaffolds new projects from
[laravel-template-vue](https://github.com/jackelvinsson/laravel-template-vue) or
[laravel-template-react](https://github.com/jackelvinsson/laravel-template-react).

## Install / update

```bash
curl -fsSL https://raw.githubusercontent.com/jackelvinsson/turbo/master/install.sh | bash
```

Running the same command again updates turbo to the latest version.

## Usage

```bash
turbo create
```

Walks through: a project name, a template choice (`vue` or `react`),
optionally creating a GitHub repo (private or public) via `gh`, cloning
the chosen template into your projects directory, and optionally
running the template's own `setup.sh` for you.

```bash
turbo destroy <project>
```

Deletes a project's local directory. If it has a GitHub remote, asks
separately whether to delete that too. Requires typing the project
name back to confirm before anything is deleted.

Deleting a GitHub repo needs the `delete_repo` scope, which `gh auth
login` doesn't grant by default. If it fails with a 403, run:

```bash
gh auth refresh -h github.com -s delete_repo
```

and follow the intructions in the terminal.

```bash
turbo update
```

Updates turbo to the latest version explicitly (this also happens
automatically, non-blockingly, as a check at the start of `turbo
create`).

## Configuration

The projects directory is set on first install (default
`/home/jack/PhpstormProjects`) and stored in `~/.config/turbo/config`.
Edit that file directly to change it on a given machine.

## Requirements

`git` and `curl` always. `gh` (authenticated via `gh auth login`) only
if you choose to create a GitHub repo.
