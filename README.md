# service-godot-build

Runs an engine repository's Windows build matrix locally by reading its workflow, and holds the workflows that release engine builds.

## What it is for

The escript parses the variant matrix, the pinned build tool and its settings from the engine's workflow at run time, so a change to the workflow changes the local build with it. The release workflows build the engine at double precision and the sandbox addon at both precisions for the hosts RFD 2293 plans for.

## Build and run

    mix escript.build
    escript godot_win_build --repo <engine checkout> --list

## Licence

Apache-2.0 OR MIT, as the SPDX headers in the source state.
