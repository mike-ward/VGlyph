# Phase 7: Vertical Coords - Context

**Gathered:** 2026-02-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Make vertical text coordinate transforms clear and exhaustive. Document transform logic inline,
ensure all orientation enum values are handled, and distinguish upright vs rotated code paths.

</domain>

<decisions>
## Implementation Decisions

### Transform documentation
- Document inline at call sites where transforms applied (follows v1.1 pattern)
- Include formula AND explanation of why transform needed
- Add ASCII diagrams where helpful for complex transforms
- Document coordinate system conventions once at top of file (+X, +Y, origin)

### Branch clarity
- Separate functions for upright vs rotated paths (clean separation)
- Suffix naming pattern: `_upright()` / `_rotated()`
- Document dispatch criteria at calling site explaining what triggers each path
- Extract common helpers for shared transform logic

### Debug validation
- Compiler switch exhaustiveness enforces all orientation enum values handled
- No runtime debug logging in transform paths (hot path)
- No additional coordinate sanity checks beyond enum completeness

### Test coverage
- Explicit test cases for each orientation path (upright AND rotated)

### Claude's Discretion
- Whether to add coordinate sanity checks where they'd catch real bugs
- Exact helper function boundaries for shared logic

</decisions>

<specifics>
## Specific Ideas

No specific requirements - open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope.

</deferred>

---

*Phase: 07-vertical-coords*
*Context gathered: 2026-02-02*
