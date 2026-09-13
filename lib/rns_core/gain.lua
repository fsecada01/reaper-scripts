-- Gain/level conversion helpers shared by restoration and mixing scripts.
local gain = {}

-- Lua 5.1's math.log only takes one argument (no base) — REAPER's embedded
-- Lua targets 5.1, so log base 10 is computed by hand rather than via the
-- two-argument math.log(x, base) form 5.2+/LuaJIT support.
local LN10 = math.log(10)

function gain.db_to_linear(db)
  return 10 ^ (db / 20)
end

function gain.linear_to_db(linear)
  assert(linear > 0, "linear_to_db requires a positive value")
  return 20 * math.log(linear) / LN10
end

return gain
