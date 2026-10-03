# Repository guidance

## Bug-driven development

- Record each bug in `docs/bugs/` using `docs/bugs/_template.md` before changing code.
- Follow the stages in `docs/bugs/README.md`: clarify the report, add and run a focused regression test, confirm it fails for the reported behavior, and only then start a fix.
- Keep the regression test and its red/green command and result in the bug report. Do not implement a fix before the red result is recorded. If a valid failing test cannot be produced, record why and leave the bug blocked instead of silently skipping the test-first step.
- Check the relevant specifications before encoding expected behavior; for game rules, follow `docs/rules-spec.md` and do not turn documented open questions into assumptions.

## Code Review Rules

- Report only high-confidence, merge-blocking regressions introduced by the PR: incorrect game outcomes, exploitable trust-boundary failures, lost or duplicated saved/multiplayer state, or broken reconnect/concurrency behavior. Prefer no finding to speculation.
- For changes to game rules, check the relevant section of `docs/rules-spec.md`. Preserve its explicit decisions and deterministic behavior; do not report documented open questions as regressions.
- For changes to JSON content or schemas, report broken runtime references, invalid player-visible content, or incompatibility with the supported `mvp` content set. CI already checks mechanical schema, formatting, and validation failures; do not repeat them unless they cause a concrete runtime problem.
- Skip style, naming, documentation-only preferences, cosmetic refactors, and requests for extra tests unless a specific serious defect depends on them. Keep each finding concise and tied to a changed line.
