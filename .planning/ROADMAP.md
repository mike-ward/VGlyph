# Roadmap: VGlyph

## Milestones

- ✅ **v1.0 Memory Safety** - Phases 1-3 (shipped 2026-02-02)
- 🚧 **v1.1 Fragile Area Hardening** - Phases 4-7 (in progress)

## Phases

<details>
<summary>✅ v1.0 Memory Safety (Phases 1-3) - SHIPPED 2026-02-02</summary>

### Phase 1: Error Propagation
**Goal**: GlyphAtlas operations return errors instead of panicking
**Plans**: 1 plan

Plans:
- [x] 01-01: Error-returning API and allocation validation

### Phase 2: Memory Safety
**Goal**: Prevent integer overflow and allocation abuse
**Plans**: 1 plan

Plans:
- [x] 02-01: Dimension validation and allocation limits

### Phase 3: Layout Safety
**Goal**: Safe string lifetime management in layout inline objects
**Plans**: 1 plan

Plans:
- [x] 03-01: String cloning and cleanup for inline object IDs

</details>

### 🚧 v1.1 Fragile Area Hardening (In Progress)

**Milestone Goal:** Harden iterator lifecycle, attribute lists, FreeType state, and coordinate transforms

#### Phase 4: Layout Iteration
**Goal**: Safe iterator lifecycle prevents misuse and resource leaks
**Depends on**: Phase 3
**Requirements**: ITER-01, ITER-02, ITER-03
**Success Criteria** (what must be TRUE):
  1. Iterator resources automatically released via defer when out of scope
  2. Iterator lifecycle rules documented inline where iterators created
  3. Reusing exhausted iterator caught in debug builds before undefined behavior
**Plans**: TBD

Plans:
- [ ] TBD

#### Phase 5: Attribute List
**Goal**: Attribute list ownership and lifecycle unambiguous
**Depends on**: Phase 4
**Requirements**: ATTR-01, ATTR-02, ATTR-03
**Success Criteria** (what must be TRUE):
  1. Ownership boundaries documented inline where AttrList created/unreffed
  2. Double-free impossible via API design (caller can't accidentally unref twice)
  3. Leaked attribute lists detected in debug builds
**Plans**: TBD

Plans:
- [ ] TBD

#### Phase 6: FreeType State
**Goal**: FreeType face state transitions validated and consistent
**Depends on**: Phase 5
**Requirements**: FT-01, FT-02, FT-03
**Success Criteria** (what must be TRUE):
  1. load→translate→render sequence documented inline at face operations
  2. Invalid state transitions caught in debug builds before FT call
  3. Fallback path state transitions match normal path (no divergence)
**Plans**: TBD

Plans:
- [ ] TBD

#### Phase 7: Vertical Coords
**Goal**: Vertical text coordinate transforms clear and exhaustive
**Depends on**: Phase 6
**Requirements**: VERT-01, VERT-02, VERT-03
**Success Criteria** (what must be TRUE):
  1. Coordinate transform logic documented inline where transforms applied
  2. All orientation enum values handled (no missing match arms)
  3. Upright vs rotated branches clearly distinguished in code
**Plans**: TBD

Plans:
- [ ] TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Error Propagation | v1.0 | 1/1 | Complete | 2026-02-01 |
| 2. Memory Safety | v1.0 | 1/1 | Complete | 2026-02-01 |
| 3. Layout Safety | v1.0 | 1/1 | Complete | 2026-02-02 |
| 4. Layout Iteration | v1.1 | 0/TBD | Not started | - |
| 5. Attribute List | v1.1 | 0/TBD | Not started | - |
| 6. FreeType State | v1.1 | 0/TBD | Not started | - |
| 7. Vertical Coords | v1.1 | 0/TBD | Not started | - |
