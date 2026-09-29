# Repository guidance

## Code Review Rules

- Report only high-confidence, merge-blocking regressions introduced by the PR: incorrect game outcomes, exploitable trust-boundary failures, lost or duplicated saved/multiplayer state, or broken reconnect/concurrency behavior. Prefer no finding to speculation.
- For changes to game rules, check the relevant section of `docs/rules-spec.md`. Preserve its explicit decisions and deterministic behavior; do not report documented open questions as regressions.
- For changes to JSON content or schemas, report broken runtime references, invalid player-visible content, or incompatibility with the supported `mvp` content set. CI already checks mechanical schema, formatting, and validation failures; do not repeat them unless they cause a concrete runtime problem.
- Skip style, naming, documentation-only preferences, cosmetic refactors, and requests for extra tests unless a specific serious defect depends on them. Keep each finding concise and tied to a changed line.
