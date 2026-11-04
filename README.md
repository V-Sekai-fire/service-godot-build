# service-godot-build

Runs an engine repository's Windows build matrix locally by reading its workflow, and holds the workflows that release engine builds.

## What it is for

The escript parses the variant matrix, the pinned build tool and its settings from the engine's workflow at run time, so a change to the workflow changes the local build with it. The release workflows build the engine at double precision and the sandbox addon at both precisions for the hosts RFD66606-2293 plans for.

## Build and run

    mix escript.build
    escript godot_win_build --repo <engine checkout> --list

To replay double.yml's Windows job on a Windows desk when no runner is at hand:

    escript godot_win_build --repo <engine checkout> --variant <cache-name> --precision double \
      --extra "module_text_server_fb_enabled=yes optimize=speed d3d12=no angle=no accesskit=no"

## Licence

MIT. See [LICENSE](LICENSE).
