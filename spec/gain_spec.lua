local gain = require("rns_core.gain")

describe("rns_core.gain", function()
  describe("db_to_linear", function()
    it("converts 0 dB to unity gain", function()
      assert.is_near(1.0, gain.db_to_linear(0), 1e-9)
    end)

    it("converts -6 dB to roughly half amplitude", function()
      assert.is_near(0.5012, gain.db_to_linear(-6), 1e-3)
    end)
  end)

  describe("linear_to_db", function()
    it("converts unity gain to 0 dB", function()
      assert.is_near(0.0, gain.linear_to_db(1.0), 1e-9)
    end)

    it("round-trips through db_to_linear", function()
      local db = -12.3
      assert.is_near(db, gain.linear_to_db(gain.db_to_linear(db)), 1e-9)
    end)

    it("rejects non-positive input", function()
      assert.has_error(function() gain.linear_to_db(0) end)
    end)
  end)
end)
