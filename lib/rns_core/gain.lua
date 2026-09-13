-- Gain/level conversion helpers shared by restoration and mixing scripts.
local gain = {}

function gain.db_to_linear(db)
  return 10 ^ (db / 20)
end

function gain.linear_to_db(linear)
  assert(linear > 0, "linear_to_db requires a positive value")
  return 20 * math.log(linear, 10)
end

return gain
