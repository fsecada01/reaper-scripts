# Restoration Scripts

REAPER Lua scripts for audio restoration: de-noise, de-hum, de-click/de-crackle,
de-ess, and similar cleanup passes.

This category is scaffolded but currently empty — scripts land here as they're
built. Each script should:

- Live as a single `.lua` file in this folder (or a subfolder if it ships its
  own assets).
- Start with a standard REAPER/ReaPack header block (`@description`,
  `@author`, `@version`, `@about`, `@links`) so it can be indexed by
  `index.xml`.
- Prefer requiring shared logic from `lib/rns_core` over duplicating
  gain/analysis math locally.
