-- Per-band RMS energy analysis over time, for restoration scripts that need
-- to know how much sub/mid/high energy a source has at each moment. Pure
-- Lua, no REAPER API calls, so it can be unit tested standalone — the
-- REAPER-side sample-pulling glue lives in lib/rns_reaper instead.
local band_analysis = {}

-- RMS below this floor is reported as this dB value instead of computing
-- log(0), so silence never produces NaN/-inf.
band_analysis.FLOOR_DB = -120.0
local FLOOR_LINEAR = 10 ^ (band_analysis.FLOOR_DB / 20)

-- Lua 5.1's math.log only takes one argument (no base) — REAPER's embedded
-- Lua targets 5.1, so log base 10/2 are computed by hand rather than via
-- the two-argument math.log(x, base) form 5.2+/LuaJIT support.
local LN2 = math.log(2)
local LN10 = math.log(10)

band_analysis.DEFAULT_WINDOW_SECONDS = 1.0

-- Empirically-validated band edges for the live-recording restoration epic
-- (see docs/backlog/live-recording-restoration.md).
band_analysis.DEFAULT_BANDS = {
  { name = "sub", low = 20, high = 120 },
  { name = "mid", low = 300, high = 3000 },
  { name = "high", low = 6000, high = 18000 },
}

local function sinh(x)
  return (math.exp(x) - math.exp(-x)) / 2
end

-- RBJ Audio Cookbook constant-skirt-gain bandpass biquad, parameterized by
-- bandwidth in octaves (rather than Q) so a band can be specified directly
-- as [low_hz, high_hz] edges.
local function make_bandpass_state(low_hz, high_hz, sample_rate)
  assert(low_hz > 0 and high_hz > low_hz, "band edges must satisfy 0 < low < high")
  assert(high_hz < sample_rate / 2, "band high edge must be below Nyquist")

  local center_hz = math.sqrt(low_hz * high_hz)
  local bandwidth_octaves = math.log(high_hz / low_hz) / LN2

  local w0 = 2 * math.pi * center_hz / sample_rate
  local sin_w0 = math.sin(w0)
  local cos_w0 = math.cos(w0)
  local alpha = sin_w0 * sinh((LN2 / 2) * bandwidth_octaves * (w0 / sin_w0))

  local b0 = alpha
  local b1 = 0.0
  local b2 = -alpha
  local a0 = 1 + alpha
  local a1 = -2 * cos_w0
  local a2 = 1 - alpha

  return {
    b0 = b0 / a0,
    b1 = b1 / a0,
    b2 = b2 / a0,
    a1 = a1 / a0,
    a2 = a2 / a0,
    x1 = 0.0,
    x2 = 0.0,
    y1 = 0.0,
    y2 = 0.0,
  }
end

local function biquad_step(state, x0)
  local y0 = state.b0 * x0 + state.b1 * state.x1 + state.b2 * state.x2 - state.a1 * state.y1 - state.a2 * state.y2
  state.x2 = state.x1
  state.x1 = x0
  state.y2 = state.y1
  state.y1 = y0
  return y0
end

local function rms_to_db(rms)
  if rms < FLOOR_LINEAR then
    return band_analysis.FLOOR_DB
  end
  return 20 * math.log(rms) / LN10
end

--- Computes per-band RMS energy over fixed-size time windows.
--- @param samples number[] plain array of mono sample values (no REAPER types)
--- @param sample_rate number samples per second
--- @param bands table[]|nil array of { name, low, high } band definitions;
---        defaults to band_analysis.DEFAULT_BANDS
--- @param window_seconds number|nil window size in seconds; defaults to
---        band_analysis.DEFAULT_WINDOW_SECONDS
--- @return table[] windows, each `{ t = <window start seconds>, <name>_db = <number>, ... }`
function band_analysis.analyze(samples, sample_rate, bands, window_seconds)
  assert(type(samples) == "table", "samples must be a plain array")
  assert(type(sample_rate) == "number" and sample_rate > 0, "sample_rate must be a positive number")

  bands = bands or band_analysis.DEFAULT_BANDS
  window_seconds = window_seconds or band_analysis.DEFAULT_WINDOW_SECONDS
  local window_samples = math.max(1, math.floor(window_seconds * sample_rate))

  local filters = {}
  for _, band in ipairs(bands) do
    filters[#filters + 1] = {
      key = band.name .. "_db",
      state = make_bandpass_state(band.low, band.high, sample_rate),
      sum_sq = 0.0,
    }
  end

  local windows = {}
  local total = #samples
  local count_in_window = 0
  local window_start_index = 1

  for i = 1, total do
    local x = samples[i]
    for _, f in ipairs(filters) do
      local y = biquad_step(f.state, x)
      f.sum_sq = f.sum_sq + y * y
    end
    count_in_window = count_in_window + 1

    if count_in_window == window_samples or i == total then
      local window = { t = (window_start_index - 1) / sample_rate }
      for _, f in ipairs(filters) do
        local rms = math.sqrt(f.sum_sq / count_in_window)
        window[f.key] = rms_to_db(rms)
        f.sum_sq = 0.0
      end
      windows[#windows + 1] = window
      count_in_window = 0
      window_start_index = i + 1
    end
  end

  return windows
end

return band_analysis
