# Save format

The save document has its own `schema_version`; it is separate from
`GameState.schemaVersion`. The current released format is **2**.

| Save version | Status | Migration |
| --- | --- | --- |
| 0 (no `schema_version`, including legacy `schemaVersion`) | Previously released | Normalize the version marker, then run the v1 migration |
| 1 | Previously released | Add the PRNG checkpoint and content set identity |
| 2 | Current | No migration |

Version 2 stores a complete authoritative `GameState`: seed and current
xorshift32 PRNG state, turn and phase cursors, board and player order, all
player/monster/boil state, deck draw and discard order, quest/campaign state,
reserves and queued replacements, pending damage and decisions, event
continuations, rules definitions, translations, log and event history. It also
records `content_set_id` and `content_set_version`; the definitions used by the
snapshot are included so a later catalog edit does not silently replace the
cards or decisions in an existing campaign.

The v1 migration initializes its PRNG checkpoint from the saved seed, matching
the behavior of the v1 client, and identifies its embedded/default content as
`mvp` version `1`. New games record their selected set identity (`mvp` or
`full`) and version `1`.

An invalid JSON document, invalid state, or schema newer than the client is a
load error. Loading never deletes or rewrites that file. The save list reports
the affected slot as damaged or unsupported while loading other slots
independently. Imports are fully decoded and validated before a target slot is
replaced. File-backed saves use a temporary sibling and atomic rename; browser
saves use one IndexedDB key per slot. Autosave is separate from the five manual
slots.
