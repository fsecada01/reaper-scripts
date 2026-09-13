-- REAPER-API glue for rns_core.band_analysis: pulls raw sample data out of a
-- media item's active take via the audio accessor API and feeds it through
-- the pure-Lua analysis module. Deliberately NOT unit tested (there's no
-- REAPER host to run CreateTakeAudioAccessor/GetAudioAccessorSamples
-- against outside the DAW) — keep this file thin, glue-only, and push all
-- real logic into lib/rns_core, which is tested. Validate this against a
-- running REAPER instance before relying on it.
local band_analysis = require("rns_core.band_analysis")

local band_energy_driver = {}

-- Samples pulled per GetAudioAccessorSamples call. Kept modest so a single
-- call's buffer stays small; the loop below just walks the item
-- start-to-end in blocks of this size.
local BLOCK_SAMPLES = 65536

--- Reads the active take of `item` end-to-end and returns Story 1's
--- per-window band energy series for it (mono-summed across all channels).
--- @param item userdata REAPER MediaItem
--- @param opts table|nil forwarded to band_analysis.analyze: { bands, window_seconds }
--- @return table[] windows, as returned by rns_core.band_analysis.analyze
function band_energy_driver.analyze_item(item, opts)
  opts = opts or {}

  local take = reaper.GetActiveTake(item)
  assert(take, "item has no active take")

  local source = reaper.GetMediaItemTake_Source(take)
  local sample_rate = reaper.GetMediaSourceSampleRate(source)
  local num_channels = reaper.GetMediaSourceNumChannels(source)
  if not num_channels or num_channels < 1 then
    num_channels = 1
  end

  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

  local accessor = reaper.CreateTakeAudioAccessor(take)
  local buffer = reaper.new_array(BLOCK_SAMPLES * num_channels)
  local samples = {}

  local position = 0.0
  while position < item_length do
    buffer.clear()
    reaper.GetAudioAccessorSamples(accessor, sample_rate, num_channels, position, BLOCK_SAMPLES, buffer)

    local block = buffer.table()
    for frame = 0, BLOCK_SAMPLES - 1 do
      -- Mono-sum multichannel takes so band_analysis only ever sees a
      -- single plain sample array.
      local sum = 0.0
      for channel = 0, num_channels - 1 do
        sum = sum + (block[frame * num_channels + channel + 1] or 0.0)
      end
      samples[#samples + 1] = sum / num_channels
    end

    position = position + (BLOCK_SAMPLES / sample_rate)
  end

  reaper.DestroyAudioAccessor(accessor)

  return band_analysis.analyze(samples, sample_rate, opts.bands, opts.window_seconds)
end

return band_energy_driver
