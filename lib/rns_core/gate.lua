-- Classifies each Story 1 analysis window as "sub-dominant" or
-- "full-range" from the mid_db - sub_db differential, with hysteresis so
-- borderline values don't cause window-to-window state chatter. Pure
-- Lua, no REAPER API calls -- same input always produces the same output.
local gate = {}

gate.SUB_DOMINANT = "sub-dominant"
gate.FULL_RANGE = "full-range"

-- 0 dB: the differential's natural zero-crossing (mid as loud as sub).
-- Below it, sub carries more energy than mid; at/above it, mid holds its
-- own. Chosen over an arbitrary offset because it's physically meaningful
-- and needs no per-source tuning -- checked against the real source's
-- differential distribution (-8.3 to +10.6 dB, median +1.5 dB; see
-- docs/backlog/live-recording-restoration.md).
gate.DEFAULT_THRESHOLD_DB = 0.0

-- Minimum time a window's raw classification must persist before the
-- gate actually flips, so a single borderline window doesn't chatter the
-- state. At the default 1s window size this is a 2-window dwell.
gate.DEFAULT_MIN_DWELL_SECONDS = 2.0

--- Classifies a Story 1 analysis series into per-window gate state.
--- @param windows table[] as returned by rns_core.band_analysis.analyze
--- @param opts table|nil { threshold_db, min_dwell_seconds }
--- @return table[] windows, each `{ t, differential_db, state }`
function gate.classify(windows, opts)
  assert(type(windows) == "table", "windows must be a plain array")

  opts = opts or {}
  local threshold_db = opts.threshold_db or gate.DEFAULT_THRESHOLD_DB
  local min_dwell_seconds = opts.min_dwell_seconds or gate.DEFAULT_MIN_DWELL_SECONDS

  local results = {}
  local state = nil
  local pending_state = nil
  local pending_since_t = nil

  for i, w in ipairs(windows) do
    local differential_db = w.mid_db - w.sub_db
    local raw_state = differential_db < threshold_db and gate.SUB_DOMINANT or gate.FULL_RANGE

    if state == nil then
      state = raw_state
    elseif raw_state == state then
      pending_state = nil
      pending_since_t = nil
    else
      if pending_state ~= raw_state then
        pending_state = raw_state
        pending_since_t = w.t
      end
      if w.t - pending_since_t >= min_dwell_seconds then
        state = raw_state
        pending_state = nil
        pending_since_t = nil
      end
    end

    results[i] = { t = w.t, differential_db = differential_db, state = state }
  end

  return results
end

return gate
