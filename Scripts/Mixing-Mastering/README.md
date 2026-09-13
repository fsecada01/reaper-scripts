# Mixing / Mastering Scripts

REAPER Lua scripts for first-pass, top-down mixing and mastering: gain
staging, bus/group processing, level balancing, and similar broad-strokes
passes intended to get a session into a reasonable starting state.

This category is scaffolded but currently empty — scripts land here as they're
built. Each script should:

- Live as a single `.lua` file in this folder (or a subfolder if it ships its
  own assets).
- Start with a standard REAPER/ReaPack header block (`@description`,
  `@author`, `@version`, `@about`, `@links`) so it can be indexed by
  `index.xml`.
- Prefer requiring shared logic from `lib/rns_core` over duplicating
  gain/analysis math locally.
