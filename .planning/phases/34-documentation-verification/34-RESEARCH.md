# Phase 34: Documentation & Verification - Research

**Researched:** 2026-02-05
**Domain:** Security documentation, IME API docs, regression testing, technical writing
**Confidence:** HIGH

## Summary

Phase 34 finalizes v1.8 by documenting the overlay API architecture and verifying all CJK IME flows work.
The phase combines security architecture documentation (view hierarchy, trust boundaries), public API docs
(overlay as primary path), and end-to-end IME regression testing.

Documentation standards emphasize making trust boundaries explicit through diagrams and clear prose. IME
documentation follows W3C patterns (lifecycle, events, coordinate systems) adapted for native APIs. Testing
uses compile-only checks (sokol GUI) plus manual verification checklist for visual/IME flows.

VGlyph already has comprehensive docs structure (SECURITY.md, IME-APPENDIX.md, EDITING.md, API.md,
ARCHITECTURE.md, README.md). Phase 33 completed overlay implementation but docs still describe dead keys
only. Need to update SECURITY.md (view walk trust boundary), README (overlay as primary), IME-APPENDIX (no
longer "future work"), and verify Japanese/Chinese/Korean work through overlay path.

**Primary recommendation:** Update existing docs to reflect Phase 33 changes, add architecture diagram to
SECURITY.md showing view hierarchy walk, manual test all three CJK IMEs in editor_demo, document Korean
first-keypress as known issue.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Markdown | CommonMark | Documentation format | Universal, GitHub-native, readable as plain text |
| V test framework | built-in | Regression testing | Native V testing, zero dependencies |
| Manual testing | N/A | IME/visual verification | No headless rendering for sokol GUI |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Mermaid | 10.x | Architecture diagrams | Inline diagrams in markdown, GitHub renders natively |
| v -check | built-in | Compile verification | Fast buildability check without window launch |
| ASCII art | N/A | Simple text diagrams | When mermaid too complex, or showing concrete NSView hierarchy |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Update in-place | Create new doc | Existing structure good, just outdated. New doc = duplication |
| Automated IME tests | Manual checklist | IME requires visual/system integration, no automation possible |
| PNG diagrams | Mermaid/ASCII | Text-based diagrams version-controllable, easier to update |

**Installation:**
```bash
# No installation needed - Markdown standard, V built-in, manual testing
```

## Architecture Patterns

### Recommended Documentation Structure
```
docs/
├── SECURITY.md          # Update: Add Obj-C view walk section
├── IME-APPENDIX.md      # Update: Move overlay from "Future" to "Current"
├── EDITING.md           # Update: Document overlay API functions
├── API.md               # Update: Add IME overlay API reference
├── ARCHITECTURE.md      # Update: Mention overlay architecture
└── README.md            # Update: Overlay as primary IME integration
```

### Pattern 1: Trust Boundary Documentation
**What:** Explicitly document where trust boundaries exist and what crosses them
**When to use:** Security-sensitive code paths like view hierarchy traversal
**Source:** [Trust Boundaries Best Practices](https://securecodingpractices.com/what-are-trust-boundaries-security/)

**Example:**
```markdown
## Trust Boundaries

VGlyph's overlay API crosses a trust boundary when discovering the MTKView:

**Trusted:** V application code (editor_demo.v)
**Boundary:** C FFI call to Obj-C view hierarchy walker
**Untrusted (potentially):** NSWindow view tree (could contain unexpected subclasses)

### View Hierarchy Walk

`vglyph_discover_mtkview_from_window()` walks NSWindow's view hierarchy using
`isKindOfClass:[MTKView class]`. This is SAFE because:
- Depth-limited to 100 levels (prevents malicious deep trees)
- Uses Obj-C runtime class checking (prevents spoofing)
- Returns NULL on failure (no crashes, fallback to global callbacks)
```

### Pattern 2: IME Lifecycle Documentation
**What:** Document composition phases, event flow, and coordinate systems
**When to use:** IME API docs where developers need to understand event sequencing
**Source:** [W3C IME API Standard](https://www.w3.org/TR/ime-api/)

**Example:**
```markdown
## Overlay API Lifecycle

1. **Creation:** `ime_overlay_create_auto(ns_window)` discovers MTKView and creates overlay
2. **Registration:** `ime_overlay_register_callbacks(handle, callbacks, user_data)`
3. **Focus:** `ime_overlay_set_focused_field(handle, "field_id")` activates overlay
4. **Event Flow:**
   - User types → macOS IME → overlay's NSTextInputClient methods
   - `setMarkedText` → `on_marked_text` callback → app updates preedit
   - `insertText` → `on_insert_text` callback → app commits text
5. **Blur:** `ime_overlay_set_focused_field(handle, "")` returns focus to MTKView
6. **Cleanup:** `ime_overlay_free(handle)` cancels composition and removes overlay
```

### Pattern 3: Manual Test Checklist
**What:** Structured checklist for manual IME verification
**When to use:** GUI/visual/IME features that can't be automated
**Source:** Phase 25 verification pattern

**Example:**
```markdown
## CJK IME Verification Checklist

Test in editor_demo with each IME:

**Japanese (Hiragana):**
- [ ] Type "konnnichiha" → see hiragana preedit underlined
- [ ] Press Space → candidate window appears
- [ ] Press Enter → kanji committed
- [ ] Escape during composition → preedit cancelled

**Chinese (Pinyin):**
- [ ] Type "nihao" → see pinyin preedit
- [ ] Number key selects candidate
- [ ] Enter commits pinyin as-is

**Korean (2-Set):**
- [ ] Type ㄱ ㅏ → see 가 formed (jamo composition)
- [ ] Backspace → decomposes 가 → ㄱ → empty
- [ ] KNOWN ISSUE: First keypress requires refocus (macOS bug)
```

### Anti-Patterns to Avoid
- **Vague security claims:** "This is secure" without explaining threat model
- **Missing coordinate systems:** IME docs need to explain top-left vs bottom-left origins
- **Automated IME tests:** Sokol has no headless mode, IME needs system integration
- **Version-specific docs:** Document behavior, not implementation details that may change

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Architecture diagrams | Image editor + PNG | Mermaid in markdown | Text-based, version-controlled, GitHub renders natively |
| Security threat model | Prose only | Structured tables + diagrams | Easier to audit, visual aids help reviewers |
| API reference | Separate wiki | Inline markdown in docs/ | Single source of truth, versioned with code |
| IME event flow | Custom format | W3C-style lifecycle docs | Familiar pattern for IME developers |

**Key insight:** Existing docs structure is solid, just needs updates to reflect Phase 33 changes. No new
documentation system needed.

## Common Pitfalls

### Pitfall 1: Documenting Implementation Instead of Interface
**What goes wrong:** Docs describe internal details that may change
**Why it happens:** Writer focuses on how code works vs what developer needs
**How to avoid:** Document public API contract, behavior, guarantees - not implementation
**Warning signs:** Docs mention private functions, internal structs, specific algorithms

**Example:**
- BAD: "The overlay uses NSLayoutConstraint.activateConstraints with leadingAnchor..."
- GOOD: "The overlay automatically resizes to match the underlying view"

### Pitfall 2: Missing Trust Boundary Explanation
**What goes wrong:** Security-sensitive code lacks threat model documentation
**Why it happens:** Developer knows it's safe, assumes reader will trust them
**How to avoid:** Explicitly document what crosses boundary, what validates, what fails safe
**Warning signs:** View hierarchy walk, FFI calls, external data without trust discussion
**Source:** [Zero Trust 2026 Best Practices](https://www.exabeam.com/explainers/zero-trust/zero-trust-in-2026-principles-technologies-and-best-practices/)

**Example:**
```markdown
## Security Analysis: View Hierarchy Walk

**Threat:** Malicious app replaces MTKView with spoofed subclass

**Mitigation:**
- `isKindOfClass:` checks runtime type, not name string
- Depth limit (100) prevents stack overflow
- NULL return on failure (no crash, fallback to global)

**Residual Risk:** None. Obj-C runtime class check cannot be spoofed.
```

### Pitfall 3: "Future Work" Sections That Are Actually Current
**What goes wrong:** Old docs say feature is "planned" when it shipped
**Why it happens:** Docs not updated when implementation completes
**How to avoid:** Audit "Future," "TODO," "Not Implemented" sections during doc phase
**Warning signs:** IME-APPENDIX.md says overlay is "future work" after Phase 33

**Fix:**
```diff
-## Future Work: CJK IME
+## CJK IME via Overlay API (v1.8+)

-The VGlyph code is prepared for CJK IME:
+VGlyph supports CJK IME via overlay API:

-- Overlay view proposed but not implemented
+- VGlyphIMEOverlayView implements NSTextInputClient
+- Auto-discovery from NSWindow via `ime_overlay_create_auto()`
```

### Pitfall 4: Skipping Coordinate System Documentation
**What goes wrong:** IME candidate window appears at wrong location
**Why it happens:** macOS uses bottom-left origin, most graphics APIs use top-left
**How to avoid:** Document coordinate system explicitly with diagram
**Warning signs:** firstRectForCharacterRange, Y-axis flips, multi-monitor issues
**Source:** [W3C IME API Annex](https://w3c.github.io/ime-api/Annex.html)

**Example:**
```markdown
## Coordinate Systems

VGlyph uses **top-left origin** (standard graphics):
- Y increases downward
- Layout.get_cursor_pos() returns top-left coords

macOS expects **bottom-left origin** (Cocoa standard):
- Y increases upward
- firstRectForCharacterRange must return screen coords

Conversion in ime_overlay_darwin.m:
```objc
// Flip Y: view height - y - height
NSRect viewRect = NSMakeRect(x, self.bounds.size.height - y - h, w, h);
NSRect screenRect = [[self window] convertRectToScreen:windowRect];
```

### Pitfall 5: Incomplete Regression Coverage
**What goes wrong:** Only test one CJK language, miss others
**Why it happens:** Assume if Japanese works, Chinese/Korean will too
**How to avoid:** Explicit checklist for all three CJK IMEs (different architectures)
**Warning signs:** Japanese-only testing, no Korean verification

**Fix:** Test matrix
| IME | Composition Style | Backspace Behavior | Commit Trigger |
|-----|-------------------|--------------------| ---------------|
| Japanese | Multi-clause, conversion | Deletes char | Enter/Space/punctuation |
| Chinese | Single preedit | Deletes char | Number key/Enter |
| Korean | Real-time syllable formation | Decomposes jamo | Space/punctuation |

## Code Examples

### Example 1: SECURITY.md View Walk Section
```markdown
## NSView Hierarchy Discovery (macOS Overlay API)

### Overview

The overlay API discovers the Metal rendering view (MTKView) by walking NSWindow's subview tree. This
enables IME integration without modifying sokol-gg.

### Security Boundaries

**Trust Boundary:** C FFI between V code and Obj-C runtime

```
[TRUSTED]                [BOUNDARY]              [UNTRUSTED/VALIDATED]
V application     -->    FFI call        -->     NSWindow view tree
editor_demo.v            vglyph_discover_        Any subviews present
                         mtkview_from_window()
```

### Implementation Safety

File: `ime_overlay_darwin.m` - `vglyph_discover_mtkview_from_window()`

**Input validation:**
- `NULL` check on NSWindow pointer (line 316-318)
- Depth limit: 100 levels max (line 294-296) — prevents stack overflow from malicious deep trees
- Type safety: `isKindOfClass:[MTKView class]` uses Obj-C runtime (line 301) — cannot be spoofed

**Failure handling:**
- Returns `NULL` on not found (line 313) — caller falls back to global IME callbacks
- No exceptions thrown — V FFI cannot catch Obj-C exceptions
- Logs to stderr on failure (line 331) — diagnosable but not fatal

**Security properties:**
1. **Cannot crash:** All paths NULL-check, depth-limited
2. **Cannot be spoofed:** Obj-C runtime validates class hierarchy
3. **Fails safe:** NULL return → global fallback still works
4. **No privilege escalation:** Only reads public view tree, no modification

### Known Limitations

- Assumes MTKView is present (sokol-gg always creates one)
- Does not validate MTKView subclass behavior (trusts sokol implementation)
- No cryptographic validation (not needed - no remote data)

### Audit Trail

Added: v1.8 (Phase 33)
Reviewed: Phase 34 security audit
Threat model: View hierarchy walk
Residual risk: NONE
```

### Example 2: README.md IME Section Update
```markdown
## 🌏 Input Method Editor (IME) Support

VGlyph provides full CJK IME support for Japanese, Chinese, and Korean input.

**macOS (Overlay API - v1.8+):**
```v
$if darwin {
    // Auto-discover MTKView and create overlay
    ns_window := C.sapp_macos_get_window()
    ime_overlay := vglyph.ime_overlay_create_auto(ns_window)

    // Register per-field callbacks
    vglyph.ime_overlay_register_callbacks(ime_overlay,
        on_marked_text, on_insert_text, on_unmark_text,
        on_get_bounds, on_clause, /* ... */,
        user_data
    )

    // Activate when field focused
    vglyph.ime_overlay_set_focused_field(ime_overlay, 'my_field_id')
}
```

**Cross-platform (Global Callbacks - v1.3+):**
```v
// Works on all platforms (macOS, Linux, Windows)
vglyph.ime_register_callbacks(
    on_marked_text, on_insert_text, on_unmark_text,
    on_get_bounds, user_data
)
```

See [EDITING.md](docs/EDITING.md) for full IME integration guide.
See [IME-APPENDIX.md](docs/IME-APPENDIX.md) for technical details and composition rendering.

**Known Issue:** Korean IME first keypress requires field refocus (macOS system bug, reported upstream).
```

### Example 3: Manual Verification Checklist
```markdown
# Phase 34 Verification Checklist

## Build Verification
- [ ] `v test .` passes (all unit tests green)
- [ ] `v -check examples/editor_demo.v` compiles without errors
- [ ] `v -check examples/demo.v` compiles (baseline non-IME test)

## Documentation Review
- [ ] SECURITY.md includes "NSView Hierarchy Discovery" section
- [ ] SECURITY.md documents trust boundary with diagram
- [ ] README.md shows overlay API as primary IME path
- [ ] IME-APPENDIX.md moves overlay from "Future Work" to current
- [ ] API.md documents `ime_overlay_*` functions
- [ ] EDITING.md shows overlay callback registration

## CJK IME Regression (Manual - macOS only)

Launch `v run examples/editor_demo.v` and verify:

### Japanese IME (Hiragana)
- [ ] Type "konnnichiha" → hiragana preedit visible with underline
- [ ] Press Space → candidate window appears near cursor
- [ ] Multiple clauses show different underline styles
- [ ] Selected clause has thicker underline
- [ ] Press Enter → kanji commits to text
- [ ] Press Escape during composition → preedit cancels (not committed)
- [ ] Switch to field 2 → composition works independently

### Chinese IME (Pinyin)
- [ ] Type "nihao" → pinyin preedit visible
- [ ] Candidate window shows numbered options
- [ ] Number keys (1-9) select candidate directly
- [ ] Space selects first candidate
- [ ] Enter commits pinyin as-is (no conversion)
- [ ] Backspace during preedit deletes characters

### Korean IME (2-Set Korean)
- [ ] Type ㄱ → see ㄱ in preedit
- [ ] Type ㅏ → see 가 formed (jamo composition)
- [ ] Type ㄴ → see 간 (syllable complete)
- [ ] Backspace → decomposes 간 → 가 → ㄱ → empty (multi-step)
- [ ] Space commits current syllable
- [ ] **KNOWN ISSUE:** First keypress may not appear (macOS bug)
  - Workaround verified: Clicking field again makes it work
  - Documented in SECURITY.md "Known Limitations"

### Multi-Field Behavior
- [ ] Click field 1 → status bar shows "IME: overlay"
- [ ] Type Japanese in field 1 → works
- [ ] Click field 2 → status bar updates, field 1 loses focus
- [ ] Type Chinese in field 2 → works independently
- [ ] Compositions don't cross fields

### Fallback Path
- [ ] Run `v run examples/editor_demo.v --global-ime`
- [ ] Status bar shows "IME: global"
- [ ] Japanese/Chinese/Korean still work (via global callbacks)

## Cross-Platform Compilation
- [ ] macOS: `v build` succeeds
- [ ] Linux: `v build` succeeds (overlay code should be $if darwin only)
- [ ] Windows: (not testable, assume Linux success = Windows success per V)

## Issues Encountered
- Document any new issues found: _______________
- Korean first-keypress confirmed (expected): YES/NO
- Any regressions from v1.7: YES/NO

**Status:** PASS/FAIL/BLOCKED
**Date:** ___________
**Tester:** ___________
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No IME docs | Dead key only (v1.3) | Jan 2026 | Basic composition documented |
| "Future work" for CJK | Overlay shipped (v1.8) | Feb 2026 | Need to update from "future" to "current" |
| Security prose only | Trust boundary diagrams | 2026 standard | [Trust boundaries now visual](https://olympixai.medium.com/making-trust-boundaries-first-class-citizens-in-protocol-architecture-7e5eb9ffe3c0) |
| Automated GUI tests | Manual checklists | Sokol limitation | No headless rendering available |

**Deprecated/outdated:**
- IME-APPENDIX.md "Future Work: CJK IME" section — overlay shipped Phase 33
- SECURITY.md missing overlay trust boundary — needs new section
- README.md missing overlay API example — shows only global callbacks

## Open Questions

1. **Should SECURITY.md include threat model for overlay cleanup during crashes?**
   - What we know: `ime_overlay_free()` handles graceful cleanup
   - What's unclear: What happens if V app crashes during composition?
   - Recommendation: Document that macOS IME auto-commits on app death (system behavior)

2. **How detailed should coordinate system explanation be?**
   - What we know: Y-flip in firstRectForCharacterRange
   - What's unclear: Should docs show full matrix math or just Y-flip formula?
   - Recommendation: Show Y-flip formula only, link to NSView coordinate docs for details

3. **Should Korean first-keypress be in SECURITY.md or IME-APPENDIX.md?**
   - What we know: It's a known limitation, not exploitable
   - What's unclear: "Limitation" vs "Known Issue" categorization
   - Recommendation: SECURITY.md "Known Limitations," IME-APPENDIX.md usage note

4. **Is v -check sufficient or should examples actually launch?**
   - What we know: v -check verifies buildability and FFI linkage
   - What's unclear: Does IME actually work or just compile?
   - Recommendation: Compile-only for CI, manual launch for Phase 34 verification

## Sources

### Primary (HIGH confidence)
- [VGlyph codebase](file:///Users/mike/Documents/github/vglyph) - Current implementation
  - ime_overlay_darwin.m — Overlay implementation with view walk
  - examples/editor_demo.v — Per-overlay usage in two fields
  - docs/SECURITY.md — Existing security doc structure
  - docs/IME-APPENDIX.md — Existing IME docs (needs update)
  - docs/API.md — Public API reference
  - docs/README.md — User-facing intro
- Phase 33 summary — Overlay API wiring complete, Japanese/Chinese/Korean working
- Phase 25 research — Verification patterns, manual testing for GUI apps

### Secondary (MEDIUM confidence)
- [Trust Boundaries Security](https://securecodingpractices.com/what-are-trust-boundaries-security/) - Structured approach to documenting security boundaries
- [Zero Trust 2026 Best Practices](https://www.exabeam.com/explainers/zero-trust/zero-trust-in-2026-principles-technologies-and-best-practices/) - Making trust explicit in architecture
- [W3C IME API Standard](https://www.w3.org/TR/ime-api/) - Lifecycle and event documentation patterns
- [Microsoft IME Requirements](https://learn.microsoft.com/en-us/windows/apps/develop/input/input-method-editors) - IME API design principles

### Tertiary (LOW confidence)
- None - All findings verified against existing codebase

## Metadata

**Confidence breakdown:**
- Documentation structure: HIGH - Existing docs are comprehensive, just need updates
- Security trust boundary: HIGH - Clear boundary, well-understood risks
- IME verification: HIGH - Phase 33 manually tested, Phase 34 confirms no regression
- Testing approach: HIGH - Phase 25 established manual checklist pattern

**Research date:** 2026-02-05
**Valid until:** 90 days (stable domain - documentation best practices change slowly)
