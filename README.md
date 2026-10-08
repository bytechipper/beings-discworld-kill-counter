# Being's Discworld Kill Counter

Track group kills by player, display totals and rates, and share reports through group say.

Requires Mallard 0.27.0 or later; targets Discworld. Install through the marketplace or import the `.mallardx` archive.

Use `/kc help` for commands. `/kc group` toggles group tracking; `/kc publish` shares totals; `/kc reset` clears counts.

## Permissions

Sends game commands and group reports. Reads the GMCP packages declared in `plugin.toml`. Stores state in per-world plugin storage. No external network access.

## Development

Run `python3 -m unittest discover -s tests -v` (requires Lua 5.4 shared library). Panel tests require Python Playwright and Chromium. Build with `python3 scripts/build.py`; the reproducible archive includes only the manifest, license, README, runtime source, panel files, and assets.

![Panel preview](docs/panel-preview.png)
