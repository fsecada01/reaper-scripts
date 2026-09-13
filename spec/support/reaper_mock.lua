-- Minimal stub of REAPER's global `reaper` API surface so that pure-logic
-- modules under lib/ can be required and unit tested with busted, outside
-- of a running REAPER instance. Extend this table as shared-library code
-- starts touching more of the real API.

_G.reaper = _G.reaper or {
  ShowConsoleMsg = function(_) end,
  GetAppVersion = function() return "7.0" end,
}
