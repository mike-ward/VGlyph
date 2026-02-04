# Phase 23: Code Consistency - Context

**Gathered:** 2026-02-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Ensure codebase follows uniform conventions for naming, structure, and formatting. This is an
audit/standardization phase — no new features, just consistency across existing code.

</domain>

<decisions>
## Implementation Decisions

### Naming conventions
- Strict V stdlib conventions: all names follow V's official style guide
- Abbreviations: Claude's discretion based on context (utf8 vs UTF8 per case)
- Struct fields/constants: follow V's specific requirements for these
- Private vs public: Claude decides prefix conventions based on V best practices

### Error handling style
- Use `!` returns for functions that can fail (V's standard error propagation)
- Propagate errors with `!` at call sites (let errors bubble up)
- No bare panics: convert to error returns; panics only for truly unrecoverable states
- Error messages: lowercase, no punctuation (V convention)

### File organization
- Test files: match existing structure (don't force new pattern)
- Split files by logical concern (one file per major type/subsystem)
- Imports: alphabetical, all together (no grouping)
- Public API at file top, private helpers below
- Platform-specific: V convention (_darwin.v, _linux.v)
- C interop: isolated in dedicated *_c.v files
- Examples: in top-level examples/ directory

### Comment standards
- Doc comments required for all `pub fn` (/// format)
- Inline comments: non-obvious logic only (comment WHY, not WHAT)
- TODO/FIXME allowed with context: TODO(reason): description
- No file header boilerplate (module declaration is sufficient)

### Claude's Discretion
- Abbreviation casing decisions (utf8 vs UTF8) per context
- Private function prefix conventions
- Specific inline comment placement

</decisions>

<specifics>
## Specific Ideas

- Follow V's official style guide as the source of truth
- Error messages should match V stdlib conventions (lowercase, terse)
- Code should be self-documenting where possible

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 23-code-consistency*
*Context gathered: 2026-02-04*
