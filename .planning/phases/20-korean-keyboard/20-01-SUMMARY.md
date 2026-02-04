# Plan 20-01 Summary: Native Overlay Key Forwarding

## Outcome: PARTIAL

Tasks 1-3 completed. Task 4 (human verification) approved with known issue.

## What Was Built

**ime_overlay_darwin.m:**
- `keyDown:` forwards to `interpretKeyEvents:` during composition for jamo handling
- `becomeFirstResponder` activates input context on focus
- `resignFirstResponder` auto-commits preedit and cleans IME state
- `cancelOperation:` handles Escape to cancel composition

**ime_bridge_macos.m:**
- Added required `doCommandBySelector:` (was missing from NSTextInputClient)
- Switched from direct `handleEvent:` to `interpretKeyEvents:`
- Input context activated before processing each event

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1-3 | (prior session) | keyDown forwarding, focus handling, Escape |
| debug | b5df8a4 | doCommandBySelector, interpretKeyEvents |

## Known Issue

**Korean IME first-keypress fails:**
- First keypress after focusing doesn't trigger composition
- Second and subsequent keypresses work correctly
- Affects Korean only; Japanese and Chinese work on first keypress

**Root cause:** Unknown. Investigated:
- NSTextInputContext.activate timing
- Lazy vs eager context creation
- handleEvent vs interpretKeyEvents
- Missing doCommandBySelector method
- Swizzling timing relative to sokol view creation

**Workaround:** User types first character twice, or clicks elsewhere then refocuses.

## Verification

| Check | Status |
|-------|--------|
| Korean jamo composition (2nd+ keypress) | PASS |
| Backspace decomposes syllable | PASS |
| Focus loss auto-commits | PASS |
| Dead keys after Korean IME | PASS |
| First keypress | FAIL (known issue) |

## Files Modified

- ime_overlay_darwin.m
- ime_bridge_macos.m
