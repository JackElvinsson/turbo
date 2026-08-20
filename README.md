```
 ______   __  __     ______     ______     ______
/\__  _\ /\ \/\ \   /\  == \   /\  == \   /\  __ \
\/_/\ \/ \ \ \_\ \  \ \  __<   \ \  __<   \ \ \/\ \
   \ \_\  \ \_____\  \ \_\ \_\  \ \_____\  \ \_____\
    \/_/   \/_____/   \/_/ /_/   \/_____/   \/_____/ v1.1.0 - Scaffold Laravel projects, fast.
```

A personal CLI that scaffolds new projects from
[laravel-template](https://github.com/jackelvinsson/laravel-template).

## Install / update

```bash
curl -fsSL https://raw.githubusercontent.com/jackelvinsson/turbo/master/install.sh | bash
```

Running the same command again updates turbo to the latest version.

## Usage

```bash
turbo create
```

Walks through: a project name, optionally creating a GitHub repo
(private or public) via `gh`, cloning `laravel-template` into your
projects directory, and optionally running the template's own
`setup.sh` for you.

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
