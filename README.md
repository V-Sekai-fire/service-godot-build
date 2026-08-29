# service-godot-build

Runs a Godot repository's own Windows build matrix locally, reading the
matrix from `.github/workflows/windows_builds.yml` rather than restating it.

    mix escript.build
    escript godot_win_build --repo <path> --list
    escript godot_win_build --repo <path> --variant windows-editor-clang

## What it reads

The workflow is the source of truth. The variant matrix, the pinned SCons
version from `godot-deps`, the global `SCONS_FLAGS`, the remaining `env:`
entries, the SDK installer steps and the `${{ }}` flag template are all
parsed at run time. Change the workflow and this follows.

## Options

| flag | effect |
| --- | --- |
| `--list` | print the parsed matrix and exit |
| `--variant NAME` | a `cache-name` from the matrix |
| `--jobs N` | SCons parallelism; defaults to physical cores minus two |
| `--cache-path P` | SCons cache; defaults to `~/.scons_cache` |
| `--skip-sdk` | skip the optional SDK installers |
| `--remove-editor` | delete `editor/` for template targets, as CI does |
| `--dry-run` | resolve and print the command without running it |

## Deliberate differences from CI

The `editor/` removal is opt-in, because CI does it to a throwaway checkout
and here it would delete engine source. The cache is user-level, shared
across checkouts of the same engine. Cache restore and save are omitted,
having no meaning outside Actions.

The default job count comes from osquery's `cpu_info`, which reports
physical cores; SCons counts logical ones and takes all but one of them.
The build runs at below-normal priority so the desktop stays responsive.
