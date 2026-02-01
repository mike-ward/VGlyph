# Codebase Concerns

**Analysis Date:** 2026-02-01

## Tech Debt

**Incomplete Accessibility Window Dimensions:**
- Issue: Root accessibility node has hardcoded 0x0 dimensions
- Files: `accessibility/manager.v:69`
- Impact: Screen readers get incorrect window bounds; affects accessibility tree
  accuracy
- Fix approach: Pass actual window size when creating AccessibilityManager or
  update dimensions on window resize events

**Duplicate Code Comment:**
- Issue: "Metrics are in Pango units" comment appears twice consecutively
- Files: `layout.v:127-128`
- Impact: Minor code quality issue; suggests incomplete refactoring
- Fix approach: Remove duplicate line 128

**Incomplete TODO Marker:**
- Issue: Pango backend Darwin platform has empty TODO block
- Files: `accessibility/backend_darwin.v:130`
- Impact: Placeholder suggests unfinished platform-specific work
- Fix approach: Complete implementation or add descriptive comment

## Memory & Safety Issues

**Direct Memory Operations in Hot Paths:**
- Issue: Unsafe memory operations (vmemcpy, vmemset, vcalloc) used in glyph atlas
- Files: `glyph_atlas.v:72`, `glyph_atlas.v:389`, `glyph_atlas.v:439`, `glyph_atlas.v:447-450`
- Impact: No bounds checking on offsets; buffer overflow possible if allocation
  fails silently
- Fix approach: Add explicit null checks after vcalloc before dereferencing;
  validate size calculations prevent integer overflow

**Unsafe Casts in Pango Iteration:**
- Issue: Unsafe pointer cast when extracting PangoLayoutRun from generic pointer
- Files: `layout.v:156`
- Impact: Segfault if Pango returns unexpected type; no runtime validation
- Fix approach: Document assumption; add optional runtime type validation in
  debug builds

**Overflow Check Present but Logic Could Fail:**
- Issue: Size overflow checks use assert but don't validate allocation actually
  succeeded
- Files: `glyph_atlas.v:49`, `glyph_atlas.v:53`, `glyph_atlas.v:73`
- Impact: Assert failures abort; production code should gracefully handle large
  dimensions
- Fix approach: Replace asserts with error returns in new_glyph_atlas;
  propagate errors upstack

**String Lifetime in Inline Objects:**
- Issue: Object ID string pointer stored in Pango attribute without lifecycle
  guarantee
- Files: `layout.v:962`
- Impact: String could be freed while Pango layout still references it;
  use-after-free possible
- Fix approach: Document requirement that style.object.id must live until
  layout is rendered; consider Arena allocation

## Performance Bottlenecks

**Atlas Reset Clears All Cached Glyphs:**
- Issue: When atlas fills, all previous glyphs are invalidated mid-frame
- Files: `glyph_atlas.v:377-384`
- Impact: Causes GPU texture re-uploads; stalls rendering pipeline; visual
  artifacts possible
- Improvement path: Implement multi-page atlas or deferred reset after frame
  boundary

**Glyph Cache Keyed on Hash Without Collision Detection:**
- Issue: Cache uses u64 hash; no collision handling implemented
- Files: `renderer.v:21`
- Impact: Hash collisions silently return wrong cached glyph (visual corruption)
- Improvement path: Add secondary validation (e.g., tuple of glyph index +
  subpixel bin); or use custom hash with collision chain

**FreeType Metrics Recomputed Per Run:**
- Issue: Underline/strikethrough metrics fetched for every glyph run
- Files: `layout.v:433-462`
- Impact: Repeated C FFI calls for identical fonts; measurable overhead
- Improvement path: Cache metrics keyed by (font, language) tuple

**Bitmap Scaling Uses Bicubic for Every Frame:**
- Issue: Color emoji (BGRA) bitmaps rescaled on every load_glyph call
- Files: `glyph_atlas.v:327`
- Impact: Expensive interpolation; high CPU usage for emoji-heavy text
- Improvement path: Cache scaled bitmaps or use GPU scaling

## Fragile Areas

**Layout Iteration State Machine:**
- Files: `layout.v:151-173`, `layout.v:184`, `layout.v:788-829`
- Why fragile: Multiple iterators over same layout; no documentation of iterator
  lifecycle; caller responsibility to free
- Safe modification: Always wrap with defer { C.pango_layout_iter_free() };
  never reuse iterator after next_run returns false
- Test coverage: Tests create layouts but don't stress-test complex iterator
  patterns

**Pango Attribute List Lifecycle:**
- Files: `layout.v:82-97`, `layout.v:282-338`, `layout.v:831-973`
- Why fragile: Nested list creation with unref() calls; easy to double-free or
  leak
- Safe modification: Document: (1) copy must be unref'd separately, (2)
  pango_layout_set_attributes transfers ownership, (3) always pair new with
  unref
- Test coverage: No tests for attribute list memory leaks

**FreeType Face Rendering State:**
- Files: `glyph_atlas.v:124-168`
- Why fragile: Load -> translate -> render sequence; fallback path reloads
  without translation
- Safe modification: Document mandatory sequence; add state validation before
  translate
- Test coverage: Only basic load_glyph tested; subpixel shifting path untested

**Vertical Text Coordinate Transformation:**
- Files: `layout.v:566-597`, `layout.v:618-627`
- Why fragile: Manual coordinate swapping based on cfg.orientation enum;
  coordinate system differs from Pango's
- Safe modification: Add comprehensive inline documentation explaining upright
  orientation logic
- Test coverage: No vertical text rendering tests

## Scaling Limits

**Glyph Atlas Fixed Max Height:**
- Capacity: 4096 pixels height
- Limit: Fonts > 4096 pt cannot be cached; extreme emoji sizes exceed atlas
- Scaling path: (1) Make max_height configurable, (2) Implement atlas paging
  with LRU eviction

**Cache Entry Map Unbounded:**
- Capacity: map[u64]CachedGlyph with no size limit
- Limit: Millions of unique glyphs cause memory bloat
- Scaling path: Implement LRU eviction with configurable max_entries; currently
  only cleared on full page reset

**Layout Hit-Test Character Rect Storage:**
- Capacity: One rect per Unicode codepoint in text
- Limit: 100,000+ character strings cause O(N) memory allocation
- Scaling path: Implement lazy rect computation on first access; store only
  range queries

## Security Considerations

**Pango Markup Injection:**
- Risk: User-supplied text can execute Pango markup features (colors, fonts,
  shapes)
- Files: `layout.v:245`
- Current mitigation: use_markup flag allows caller to opt-in; default is off
- Recommendations: (1) Document markup security implications, (2) Add HTML
  entity escaping utility, (3) Validate markup syntax before passing to Pango

**FreeType Integer Overflow in Size Calculations:**
- Risk: Large dimensions multiply to exceed u32 bounds
- Files: `glyph_atlas.v:52`, `glyph_atlas.v:213-215`
- Current mitigation: Overflow checks present but use asserts
- Recommendations: (1) Use signed overflow checking, (2) Replace asserts with
  error propagation in production code

**Unsafe Pointer Arithmetic:**
- Risk: Manual pointer offset calculations (e.g., row_bytes multiplication)
- Files: `glyph_atlas.v:483-488`
- Current mitigation: Bounds validation in copy_bitmap_to_atlas
- Recommendations: (1) Extract offset calculations to typed functions, (2) Add
  saturating arithmetic

## Dependencies at Risk

**FreeType Without Version Constraint:**
- Risk: API changes across major versions; code targets FT 2.x but no explicit
  version bound
- Impact: Compilation failures on FT 3.x; subpixel unit constants may differ
- Migration plan: (1) Pin pkgconfig to freetype2, (2) Test against FT 2.13+,
  (3) Document minimum version in v.mod

**Pango Without Fallback:**
- Risk: Pango 1.50+ removed deprecated APIs; code uses pango_ft2_*
- Impact: Will not compile on Pango 2.0 (if released); no alternative backend
- Migration plan: (1) Research Pango 2.0 roadmap, (2) Add feature flags for API
  variants, (3) Plan gradual migration

## Test Coverage Gaps

**Untested Error Paths:**
- What's not tested: (1) OOM scenarios in atlas allocation, (2) FreeType load
  failures, (3) Pango context initialization failure recovery
- Files: `glyph_atlas.v`, `context.v`, `layout.v`
- Risk: Silent failures or asserts in production; no graceful degradation
- Priority: High

**Untested Edge Cases:**
- What's not tested: (1) Empty layout with hit_test(), (2) Negative dimensions,
  (3) RTL text with vertical layout, (4) Emoji with custom object sizing
- Files: `layout.v`, `layout_query.v`
- Risk: Undefined behavior on boundary conditions
- Priority: Medium

**Untested Memory Stress:**
- What's not tested: (1) Repeated atlas resets, (2) Map cache unbounded growth,
  (3) Layout with millions of characters
- Files: `glyph_atlas.v`, `renderer.v`
- Risk: Memory leaks or performance degradation under stress
- Priority: Medium

**No Thread Safety Tests:**
- What's not tested: (1) Concurrent layout creation, (2) Shared context thread
  safety
- Files: `context.v`, `layout.v`
- Risk: VGlyph is not thread-safe (Pango/FreeType are not); concurrent use
  causes data corruption
- Priority: Low (V is single-threaded by design, but document assumption)

---

*Concerns audit: 2026-02-01*
