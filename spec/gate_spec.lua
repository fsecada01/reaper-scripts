local gate = require("rns_core.gate")

local function windows_from_differentials(diffs, window_seconds)
  window_seconds = window_seconds or 1.0
  local windows = {}
  for i, d in ipairs(diffs) do
    windows[i] = { t = (i - 1) * window_seconds, sub_db = -30.0, mid_db = -30.0 + d, high_db = -50.0 }
  end
  return windows
end

describe("rns_core.gate", function()
  describe("classify", function()
    it("classifies a steady full-range series as full-range throughout", function()
      local result = gate.classify(windows_from_differentials({ 5, 5, 5, 5 }))
      for _, w in ipairs(result) do
        assert.equals(gate.FULL_RANGE, w.state)
      end
    end)

    it("classifies a steady sub-dominant series as sub-dominant throughout", function()
      local result = gate.classify(windows_from_differentials({ -5, -5, -5, -5 }))
      for _, w in ipairs(result) do
        assert.equals(gate.SUB_DOMINANT, w.state)
      end
    end)

    it("is deterministic: same input always produces the same output", function()
      local windows = windows_from_differentials({ 5, -5, 5, -2, -8, 3, 6 })
      assert.same(gate.classify(windows), gate.classify(windows))
    end)

    it("holds the initial raw state immediately with no dwell requirement", function()
      local result = gate.classify(windows_from_differentials({ -5 }))
      assert.equals(gate.SUB_DOMINANT, result[1].state)
    end)

    it("does not flip on a brief crossing shorter than the dwell time", function()
      local result = gate.classify(windows_from_differentials({ 5, 5, -5, 5, 5 }))
      for _, w in ipairs(result) do
        assert.equals(gate.FULL_RANGE, w.state, "brief dip should not flip the gate")
      end
    end)

    it("flips once the opposite state holds for at least the dwell time", function()
      local result = gate.classify(windows_from_differentials({ 5, 5, -5, -5, -5, -5 }))
      assert.equals(gate.FULL_RANGE, result[1].state)
      assert.equals(gate.FULL_RANGE, result[2].state)
      assert.equals(gate.FULL_RANGE, result[3].state, "not enough dwell yet")
      assert.equals(gate.FULL_RANGE, result[4].state, "dwell reaches 1s here, still short of 2s")
      assert.equals(gate.SUB_DOMINANT, result[5].state, "dwell reaches 2s, gate flips")
      assert.equals(gate.SUB_DOMINANT, result[6].state)
    end)

    it("resets the dwell timer if the raw state returns to the current gate state", function()
      local result = gate.classify(windows_from_differentials({ 5, 5, -5, 5, -5, -5, -5 }))
      assert.equals(gate.FULL_RANGE, result[4].state)
      assert.equals(gate.FULL_RANGE, result[5].state, "dwell restarts here")
      assert.equals(gate.FULL_RANGE, result[6].state, "only 1s of dwell so far")
      assert.equals(gate.SUB_DOMINANT, result[7].state, "2s dwell reached, gate flips")
    end)

    it("honors a custom threshold and dwell time", function()
      local windows = windows_from_differentials({ 1, 1, -1, -1 })
      local result = gate.classify(windows, { threshold_db = 2.0, min_dwell_seconds = 0.5 })
      for _, w in ipairs(result) do
        assert.equals(gate.SUB_DOMINANT, w.state)
      end
    end)

    it("reports the raw differential alongside the (possibly lagged) state", function()
      local result = gate.classify(windows_from_differentials({ 5, 5, -5 }))
      assert.is_near(-5, result[3].differential_db, 1e-9)
      assert.equals(gate.FULL_RANGE, result[3].state)
    end)
  end)
end)
