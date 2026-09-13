# 0001. Multiband crossover/filter topology for restoration

**Status**: accepted
**Date**: 2026-09-13
**Related**: [Live-recording restoration epic](../docs/backlog/live-recording-restoration.md) — Story 1 (band-energy analysis), Story 3 (FX chain assembly)

## Context

This epic restores a degraded, phone-recorded live show
(sub-bass-heavy, mid/high-starved) by having Lua analyze the item and then
programmatically configure REAPER's native plugins (ReaXcomp, ReaEQ,
ReaGate) — no custom JSFX/DSP (see the epic's own DSP-approach decision).

Two separate places in that pipeline involve band-splitting filters, and
it wasn't obvious they should use the same filter design:

1. **Story 1** (`lib/rns_core/band_analysis.lua`) — RBJ-cookbook biquad
   bandpass filters used purely for offline analysis (RMS energy per
   band, never played back).
2. **Story 3** (FX chain assembly) — ReaXcomp's band split + ReaEQ shelving
   in the actual audible signal path.

The concern raised: a single 2nd-order biquad bandpass is a fairly blunt
instrument, and it wasn't clear whether "more precise" (steeper/brickwall)
filtering would actually sound better for *restoring* already-degraded,
transient-heavy material, or whether precision and "musicality" trade off
against each other here. We ran deep research (Tavily `pro`, 16 sources;
full output preserved in `claudedocs/research_multiband_filter_topology_20260913.md`,
gitignored/local) comparing filter topologies specifically for this
restoration use case.

## Decision

**Story 1 (analysis) is unaffected — no change.** The existing RBJ biquad
bandpass approach is appropriate as-is: this filtering is inaudible
(analysis-only), and zero-phase (forward/backward, phase-cancelling)
filtering has no pre-ring concern since nothing is ever played back through
it. 4th-order-equivalent selectivity is sufficient for classifying windows.

**Story 3 (audible signal path) should prefer minimum-phase, moderately
steep splits over brickwall/linear-phase ones:**

- Prefer **Linkwitz-Riley 4th-order (LR4, 24 dB/oct)** — built from two
  cascaded Butterworth biquad sections tuned for phase-aligned crossover
  summing — as the default crossover shape if/when a hard band split is
  needed. This is the industry-standard choice for multiband compressors
  and is transient-friendly.
- **Avoid** high-order elliptic filters and FFT/FIR linear-phase
  "brickwall" crossovers for this material. Both introduce time-domain
  artifacts (ringing / pre-ringing) that read as unmusical, and those
  artifacts are *more* audible on transient-heavy, already-degraded
  material (phone mic, crowd noise, amp bleed) than the spectral precision
  gained from a steeper slope.
- For the starved high ("air") band specifically: prefer a **broad,
  gentle high-shelf/bell EQ (ReaEQ) + upward expansion** over a hard
  bandpass split. The empirical baseline (see epic doc) shows the high
  band is *nearly always* starved (median -41.3 dB, staying below -29.2 dB
  through validation against the real source) rather than only
  intermittently starved, so an always-on gentle lift still fits the data
  better than a gated multiband split, and carries lower artifact risk —
  but -29.2 dB is a high watermark from one validation run, not a proven
  hard ceiling, so this should be re-checked once Story 3 has more of the
  source to test against.
- **Resolved: build Story 3 directly against ReaXcomp, skip the
  pre-emptive impulse-response spike.** ReaXcomp's internal crossover
  topology (IIR vs. FFT/linear-phase) is still not documented publicly,
  but rather than block Story 3 on a standalone validation spike, ship
  the initial FX-chain script using ReaXcomp's native band split and
  evaluate it by ear/measurement against the real source once built. If
  it turns out to introduce audible pre-ring/smearing, the fallback
  options are (a) a custom JSFX plugin doing the split manually (the
  epic's broader "no custom JSFX/DSP" stance is about the *decision*
  logic staying pure-Lua, not a hard ban on a JSFX band-splitter if
  ReaXcomp's turns out to be unusable), or (b) a third-party
  multiband tool (e.g. something from Tukan Audio) in place of
  ReaXcomp. Neither is being built now — noted here so it isn't
  rediscovered from scratch later.

## Consequences

- Story 1 proceeds unchanged; this ADR doesn't block it.
- Story 3 builds directly against ReaXcomp's native band split (no
  upfront validation spike), and should default the high band to
  shelf+expansion rather than a hard split unless testing shows
  otherwise.
- If ReaXcomp's split proves audibly problematic once built, Story 3
  (or a follow-up) gets more complex — manual LR4-style ReaEQ cascade,
  a custom JSFX splitter, or a third-party tool (e.g. Tukan Audio)
  instead of ReaXcomp's default — flagged here so it doesn't surprise
  estimation later.
- No numeric threshold/ratio/attack-release starting values came out of
  the research; Story 2/3 still need to derive those empirically from the
  analysis output.

## Alternatives considered

| Option | Rejected because |
|---|---|
| Elliptic (Cauer) crossover | Steepest rolloff per order, but equiripple + pronounced delay distortion near cutoff → more ringing/overshoot on percussive/lo-fi source |
| FIR linear-phase / FFT brickwall crossover | Constant group delay, but symmetric pre-ringing + added latency; risks smearing transients / audible pre-echo on this material |
| Plain single-order Butterworth biquad (no LR cascade) | Under-selective on its own; LR4 (cascaded biquads) achieves the needed selectivity without giving up minimum-phase behavior |
| Analog-modeled SVF (TPT, Zavalishin) | Viable minimum-phase alternative to LR4 with an "analog" character; not rejected outright, just not chosen as the default — worth prototyping later if LR4 sounds too clinical |
