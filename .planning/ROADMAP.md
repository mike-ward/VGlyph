# Roadmap

## Milestone: Pango RAII Refactor
Refactor manual memory management of Pango pointers into V structs with RAII-like ownership.

### Phase 35: Pango Ownership
**Goal:** Implement Pango wrappers and refactor codebase to use them for safer memory management.
**Status:** [In Progress]
**Plans:**
- [ ] 35-01-PLAN.md — Core Pango wrappers
- [ ] 35-02-PLAN.md — Refactor Context and Attributes
- [ ] 35-03-PLAN.md — Refactor Layout and Pango Integration
- [ ] 35-04-PLAN.md — Final cleanup and verification

### Phase 36: Integration Testing
**Goal:** Replace 'unsafe { nil }' mocks in unit tests with real Pango/Cairo backend interactions to ensure C-binding and layout logic integrity.
**Status:** [Planned]
**Plans:**
- [ ] 36-01-PLAN.md — Integration Test Infrastructure
- [ ] 36-02-PLAN.md — API Test Refactor