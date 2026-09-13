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
  band is *always* starved (never above -32 dB, not intermittently), so
  an always-on gentle lift fits the data better than a gated multiband
  split, and carries lower artifact risk.
- **Open question, needs a spike before Story 3 relies on it**:
  ReaXcomp's internal crossover topology (IIR vs. FFT/linear-phase) is
  not documented publicly. Before trusting it for restoration-quality
  work, capture its impulse response and inspect group delay / pre-ring
  through the band-split-and-sum chain. If it turns out to be
  steep/FFT-based, build the sub/mid split manually via cascaded ReaEQ
  bands approximating LR4 instead of trusting ReaXcomp's default.
  (ReaEQ itself is documented by the REAPER community as *not*
  linear-phase, i.e. minimum-phase — consistent with what we want.)

## Consequences

- Story 1 proceeds unchanged; this ADR doesn't block it.
- Story 3's design should budget for the ReaXcomp impulse-response spike
  before finalizing its FX chain, and should default the high band to
  shelf+expansion rather than a hard split unless testing shows otherwise.
- If the spike finds ReaXcomp uses a steep/FFT crossover, Story 3 gets
  more complex (manual LR4-style ReaEQ cascade instead of relying on
  ReaXcomp's native split) — flagged here so it doesn't surprise
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
