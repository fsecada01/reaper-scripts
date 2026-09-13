local band_analysis = require("rns_core.band_analysis")

local SAMPLE_RATE = 48000

local function band_center(band)
  return math.sqrt(band.low * band.high)
end

local function find_band(name)
  for _, band in ipairs(band_analysis.DEFAULT_BANDS) do
    if band.name == name then
      return band
    end
  end
  error("no such band: " .. name)
end

local function sine_wave(freq, duration_seconds, amplitude)
  amplitude = amplitude or 1.0
  local n = math.floor(duration_seconds * SAMPLE_RATE)
  local samples = {}
  for i = 0, n - 1 do
    samples[i + 1] = amplitude * math.sin(2 * math.pi * freq * i / SAMPLE_RATE)
  end
  return samples
end

local function silence(duration_seconds)
  local n = math.floor(duration_seconds * SAMPLE_RATE)
  local samples = {}
  for i = 1, n do
    samples[i] = 0.0
  end
  return samples
end

describe("rns_core.band_analysis", function()
  describe("analyze", function()
    it("classifies a sub-band sine wave as sub-dominant energy", function()
      local sub = find_band("sub")
      local samples = sine_wave(band_center(sub), 1.0)

      local windows = band_analysis.analyze(samples, SAMPLE_RATE)

      assert.equals(1, #windows)
      local w = windows[1]
      assert.equals(0.0, w.t)
      assert.is_true(w.sub_db > -10, "expected sub_db near full signal level, got " .. w.sub_db)
      assert.is_true(w.sub_db > w.mid_db + 10, "expected sub band to dominate mid band")
      assert.is_true(w.sub_db > w.high_db + 10, "expected sub band to dominate high band")
    end)

    it("classifies a mid-band sine wave as mid-dominant energy", function()
      local mid = find_band("mid")
      local samples = sine_wave(band_center(mid), 1.0)

      local windows = band_analysis.analyze(samples, SAMPLE_RATE)

      local w = windows[1]
      assert.is_true(w.mid_db > -10, "expected mid_db near full signal level, got " .. w.mid_db)
      assert.is_true(w.mid_db > w.sub_db + 10, "expected mid band to dominate sub band")
      assert.is_true(w.mid_db > w.high_db + 10, "expected mid band to dominate high band")
    end)

    it("classifies a high-band sine wave as high-dominant energy", function()
      local high = find_band("high")
      local samples = sine_wave(band_center(high), 1.0)

      local windows = band_analysis.analyze(samples, SAMPLE_RATE)

      local w = windows[1]
      assert.is_true(w.high_db > -10, "expected high_db near full signal level, got " .. w.high_db)
      assert.is_true(w.high_db > w.sub_db + 10, "expected high band to dominate sub band")
      assert.is_true(w.high_db > w.mid_db + 10, "expected high band to dominate mid band")
    end)

    it("reports the floor dB for silence instead of NaN/erroring", function()
      local samples = silence(1.0)

      local windows = band_analysis.analyze(samples, SAMPLE_RATE)

      assert.equals(1, #windows)
      local w = windows[1]
      for _, band in ipairs(band_analysis.DEFAULT_BANDS) do
        local value = w[band.name .. "_db"]
        assert.equals(band_analysis.FLOOR_DB, value)
        assert.is_true(value == value, "value should not be NaN") -- NaN fails self-equality
      end
    end)

    it("honors custom band definitions and window size", function()
      local samples = sine_wave(1000, 2.0)
      local custom_bands = { { name = "wide", low = 100, high = 15000 } }

      local windows = band_analysis.analyze(samples, SAMPLE_RATE, custom_bands, 0.5)

      assert.equals(4, #windows)
      assert.is_not_nil(windows[1].wide_db)
      assert.is_nil(windows[1].sub_db)
      assert.equals(0.0, windows[1].t)
      assert.equals(0.5, windows[2].t)
    end)

    it("defaults to a 1-second window over sub/mid/high bands", function()
      local samples = silence(2.5)

      local windows = band_analysis.analyze(samples, SAMPLE_RATE)

      -- Two full 1-second windows plus one trailing partial (0.5s) window.
      assert.equals(3, #windows)
      assert.equals(0.0, windows[1].t)
      assert.equals(1.0, windows[2].t)
      assert.equals(2.0, windows[3].t)
    end)
  end)
end)
