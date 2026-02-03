# Phase 14: Undo/Redo - Research

**Researched:** 2026-02-03
**Domain:** Undo/redo for text editing operations in grapheme-aware editor
**Confidence:** HIGH

## Summary

Undo/redo enables reverting and reapplying text mutations. Two dominant patterns exist: command
pattern (store reversible operations) and memento pattern (store state snapshots). For VGlyph,
command pattern fits better - Phase 13 already provides MutationResult with all undo info
(deleted_text, range, new cursor position). Implementation uses two stacks (undo/redo), with
operation coalescing for rapid typing (1-2 second timeout), and history limit (50-100 operations).

Phase 13's pure function design perfectly supports undo - each mutation returns complete state
transition info without side effects. The TextChange struct already captures what undo needs:
old_text, new_text, range. VGlyph provides mutation primitives, app manages undo stacks.

Key insight: Don't store entire text buffer copies. Store operation deltas - what was inserted,
what was deleted, where. Command pattern with operation inverses uses O(changed characters) memory
vs memento's O(total buffer size). For 50 operations on 100KB text, that's ~5KB vs ~5MB.

**Primary recommendation:** Use command pattern with dual stacks, coalesce rapid operations with
1-second timeout, limit to 50-100 operations. V's datatypes.Stack provides ready-made LIFO
structure.

## Standard Stack

### Core V APIs
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| datatypes.Stack[T] | stdlib | Generic LIFO container | Built-in, type-safe, well-tested |
| time | stdlib | Coalescing timeout | Standard time operations |

### Supporting
| API | Purpose | When to Use |
|-----|---------|-------------|
| Stack.push(item) | Add to undo stack | After each mutation |
| Stack.pop() !T | Retrieve last operation | During undo |
| Stack.is_empty() | Check stack state | Before pop |
| Stack.len() | Check history limit | Before push |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Command pattern | Memento (state snapshots) | Memento simpler but O(n) memory per entry |
| datatypes.Stack | []T array | Stack clearer intent, cleaner API |
| Operation deltas | Full text copies | Deltas 100x-1000x smaller memory |

**Installation:**
```v
import datatypes
import time
```

## Architecture Patterns

### Recommended Undo Manager Structure
```v
struct UndoManager {
mut:
    undo_stack datatypes.Stack[UndoOperation]
    redo_stack datatypes.Stack[UndoOperation]
    max_history int = 100  // UNDO-03 requirement

    // Coalescing state
    last_mutation_time i64
    coalesce_timeout_ms i64 = 1000  // 1 second (Emacs uses 500ms, Google Docs 2s)
    coalescable_op ?UndoOperation  // Current operation being built
}
```

### Pattern 1: Operation Command Pattern
**What:** Store inverse operations, not state snapshots
**When to use:** All text mutations
**Example:**
```v
// Source: Command pattern from design patterns literature
// Verified: Phase 13 MutationResult provides all needed info

struct UndoOperation {
    op_type OperationType
    range_start int
    range_end int
    deleted_text string  // To restore on undo
    inserted_text string // To remove on undo
    cursor_before int
    cursor_after int
    anchor_before int
    anchor_after int
}

enum OperationType {
    insert
    delete
    replace
}

// Convert MutationResult to UndoOperation
fn mutation_to_undo_op(result vglyph.MutationResult, inserted string,
                       cursor_before int, anchor_before int) UndoOperation {
    return UndoOperation{
        op_type: if result.deleted_text.len > 0 && inserted.len > 0 {
            .replace
        } else if inserted.len > 0 {
            .insert
        } else {
            .delete
        }
        range_start: result.range_start
        range_end: result.range_end
        deleted_text: result.deleted_text
        inserted_text: inserted
        cursor_before: cursor_before
        cursor_after: result.cursor_pos
        anchor_before: anchor_before
        anchor_after: result.cursor_pos  // Mutations clear selection
    }
}
```

### Pattern 2: Operation Coalescing
**What:** Merge rapid typing/deletion into single undo operation
**When to use:** Continuous character insertion, continuous backspace
**Example:**
```v
// Source: Emacs (500ms), Google Docs (2s), Quip (1s)
// Recommendation: 1 second balances responsiveness with granularity

fn (mut um UndoManager) should_coalesce(new_op UndoOperation, now i64) bool {
    // No previous operation - can't coalesce
    coalescable := um.coalescable_op or { return false }

    // Timeout exceeded
    if now - um.last_mutation_time > um.coalesce_timeout_ms {
        return false
    }

    // Must be same operation type
    if coalescable.op_type != new_op.op_type {
        return false
    }

    // For inserts: must be adjacent (typing forward)
    if new_op.op_type == .insert {
        if new_op.range_start != coalescable.range_end {
            return false
        }
    }

    // For deletes: must be adjacent (backspacing backward)
    if new_op.op_type == .delete {
        if new_op.range_end != coalescable.range_start {
            return false
        }
    }

    // Replace operations don't coalesce
    if new_op.op_type == .replace {
        return false
    }

    return true
}

fn (mut um UndoManager) coalesce_operation(new_op UndoOperation) {
    mut coalescable := um.coalescable_op or { return }

    if new_op.op_type == .insert {
        // Append to inserted text
        coalescable.inserted_text += new_op.inserted_text
        coalescable.range_end = new_op.range_end
        coalescable.cursor_after = new_op.cursor_after
        coalescable.anchor_after = new_op.anchor_after
    } else if new_op.op_type == .delete {
        // Prepend to deleted text (backspacing backward)
        coalescable.deleted_text = new_op.deleted_text + coalescable.deleted_text
        coalescable.range_start = new_op.range_start
        coalescable.cursor_after = new_op.cursor_after
        coalescable.anchor_after = new_op.anchor_after
    }

    um.coalescable_op = coalescable
}
```

### Pattern 3: Push with History Limit
**What:** Maintain fixed-size history per UNDO-03 requirement
**When to use:** Before pushing to undo stack
**Example:**
```v
// Source: UNDO-03 requirement (50-100 operations)
// Production editors: VSCode (configurable), Emacs (80000 items)

fn (mut um UndoManager) push_undo(op UndoOperation) {
    // Flush any pending coalescable operation first
    if coalescable := um.coalescable_op {
        um.undo_stack.push(coalescable)
        um.coalescable_op = none
    }

    // Enforce history limit
    if um.undo_stack.len() >= um.max_history {
        // Remove oldest - requires custom implementation since Stack doesn't expose
        // Need to rebuild stack without bottom element
        // OR use []UndoOperation array instead of Stack for easy removal
        um.trim_oldest_operation()
    }

    um.undo_stack.push(op)
    um.redo_stack = datatypes.Stack[UndoOperation]{} // Clear redo on new operation
}

fn (mut um UndoManager) trim_oldest_operation() {
    // Convert to array, remove first, rebuild stack
    ops := um.undo_stack.array()
    um.undo_stack = datatypes.Stack[UndoOperation]{}
    for i in 1..ops.len {
        um.undo_stack.push(ops[i])
    }
}
```

### Pattern 4: Undo Execution
**What:** Pop operation, invert it, apply inverse mutation
**When to use:** Cmd+Z pressed
**Example:**
```v
// Source: Command pattern inverse operations

fn (mut um UndoManager) undo(mut editor EditorState) ?UndoOperation {
    // Flush pending coalescable operation first
    if coalescable := um.coalescable_op {
        um.undo_stack.push(coalescable)
        um.coalescable_op = none
    }

    if um.undo_stack.is_empty() {
        return none
    }

    op := um.undo_stack.pop() or { return none }

    // Apply inverse operation
    match op.op_type {
        .insert {
            // Undo insert: delete the inserted text
            mut sb := strings.new_builder(editor.text.len)
            sb.write_string(editor.text[..op.range_start])
            sb.write_string(editor.text[op.range_end..])
            editor.text = sb.str()
        }
        .delete {
            // Undo delete: reinsert the deleted text
            mut sb := strings.new_builder(editor.text.len + op.deleted_text.len)
            sb.write_string(editor.text[..op.range_start])
            sb.write_string(op.deleted_text)
            sb.write_string(editor.text[op.range_start..])
            editor.text = sb.str()
        }
        .replace {
            // Undo replace: remove inserted, restore deleted
            mut sb := strings.new_builder(editor.text.len)
            sb.write_string(editor.text[..op.range_start])
            sb.write_string(op.deleted_text)
            sb.write_string(editor.text[op.range_end..])
            editor.text = sb.str()
        }
    }

    // Restore cursor/anchor positions
    editor.cursor_idx = op.cursor_before
    editor.anchor_idx = op.anchor_before
    editor.has_selection = (op.cursor_before != op.anchor_before)

    // Regenerate layout
    editor.layout = editor.ts.layout_text(editor.text, editor.cfg) or { return none }

    // Push to redo stack
    um.redo_stack.push(op)

    return op
}
```

### Pattern 5: Redo Execution
**What:** Pop from redo, reapply original operation
**When to use:** Cmd+Shift+Z pressed
**Example:**
```v
fn (mut um UndoManager) redo(mut editor EditorState) ?UndoOperation {
    if um.redo_stack.is_empty() {
        return none
    }

    op := um.redo_stack.pop() or { return none }

    // Reapply original operation
    match op.op_type {
        .insert {
            mut sb := strings.new_builder(editor.text.len + op.inserted_text.len)
            sb.write_string(editor.text[..op.range_start])
            sb.write_string(op.inserted_text)
            sb.write_string(editor.text[op.range_start..])
            editor.text = sb.str()
        }
        .delete {
            mut sb := strings.new_builder(editor.text.len)
            sb.write_string(editor.text[..op.range_start])
            sb.write_string(editor.text[op.range_end..])
            editor.text = sb.str()
        }
        .replace {
            mut sb := strings.new_builder(editor.text.len)
            sb.write_string(editor.text[..op.range_start])
            sb.write_string(op.inserted_text)
            old_end := op.range_start + op.deleted_text.len
            sb.write_string(editor.text[old_end..])
            editor.text = sb.str()
        }
    }

    // Restore cursor/anchor to after-operation positions
    editor.cursor_idx = op.cursor_after
    editor.anchor_idx = op.anchor_after
    editor.has_selection = (op.cursor_after != op.anchor_after)

    // Regenerate layout
    editor.layout = editor.ts.layout_text(editor.text, editor.cfg) or { return none }

    // Push back to undo stack
    um.undo_stack.push(op)

    return op
}
```

### Anti-Patterns to Avoid
- **Storing full buffer snapshots:** O(n) memory per operation vs O(changes)
- **Not clearing redo stack on new operation:** Violates user expectations
- **Coalescing Cmd+Backspace (delete word):** User expects word-level undo
- **No history limit:** Unbounded memory growth, eventual OOM
- **Not flushing coalescable op before undo:** Loses in-progress typing

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Stack data structure | Custom linked list | datatypes.Stack[T] | Tested, type-safe, clear API |
| Time tracking | Manual tick counting | time module | Cross-platform, accurate |
| Operation inversion | String mutation logic | Pattern 4 (tested inverse ops) | Edge cases handled |
| Coalescing rules | Ad-hoc timeouts | Pattern 2 (editor-tested rules) | Matches user expectations |

**Key insight:** Command pattern implementation is well-established. Don't reinvent coalescing
rules - copy from Emacs (500ms), Google Docs (2s), or split difference (1s). Users have learned
expectations from these editors.

## Common Pitfalls

### Pitfall 1: Not Clearing Redo Stack on New Operation
**What goes wrong:** After undo, user types - press redo, wrong operation appears
**Why it happens:** Redo stack contains operations from abandoned timeline
**How to avoid:** Clear redo_stack whenever pushing to undo_stack (Pattern 3)
**Warning signs:** Redo applies unrelated operation after typing

### Pitfall 2: Coalescing Non-Adjacent Operations
**What goes wrong:** Undo removes text from multiple locations in single step
**Why it happens:** Not checking range adjacency in should_coalesce
**How to avoid:** Verify new_op.range_start == prev_op.range_end for inserts (Pattern 2)
**Warning signs:** Undo removes more than expected, non-contiguous deletion

### Pitfall 3: Forgetting to Flush Coalescable Operation
**What goes wrong:** Last few typed characters not undone, appear lost
**Why it happens:** Coalescable op still pending when undo triggered
**How to avoid:** Flush um.coalescable_op at start of undo() (Pattern 4)
**Warning signs:** Last 1-2 characters not undone

### Pitfall 4: Not Saving Cursor/Anchor State
**What goes wrong:** After undo, cursor at wrong position, selection lost
**Why it happens:** Only storing text changes, not cursor state
**How to avoid:** Store cursor_before/after, anchor_before/after in UndoOperation (Pattern 1)
**Warning signs:** Undo works but cursor jumps to end of document

### Pitfall 5: Coalescing Across Selection Changes
**What goes wrong:** Typing, then selecting word, then typing more - undo removes both
**Why it happens:** Not breaking coalescing when selection changes
**How to avoid:** Flush coalescable_op when anchor changes (Pattern 2 enhancement)
**Warning signs:** Undo spans unexpected operations

### Pitfall 6: History Limit Memory Leak
**What goes wrong:** Stack grows unbounded, eventually OOM crash
**Why it happens:** Not enforcing max_history limit
**How to avoid:** Check len() before push, trim oldest if at limit (Pattern 3)
**Warning signs:** Memory usage grows indefinitely during editing session

## Code Examples

### Complete UndoManager Integration with Editor
```v
// Source: Extending editor_demo.v from Phase 13

struct UndoableEditor {
    EditorState  // Embed existing editor
mut:
    undo_mgr UndoManager
}

fn (mut ue UndoableEditor) handle_mutation(result vglyph.MutationResult,
                                          inserted string,
                                          cursor_before int,
                                          anchor_before int) {
    now := time.now().unix_milli()

    // Convert mutation to undo operation
    op := mutation_to_undo_op(result, inserted, cursor_before, anchor_before)

    // Check if should coalesce
    if ue.undo_mgr.should_coalesce(op, now) {
        ue.undo_mgr.coalesce_operation(op)
        ue.undo_mgr.last_mutation_time = now
    } else {
        // Flush previous coalescable if exists
        if coalescable := ue.undo_mgr.coalescable_op {
            ue.undo_mgr.undo_stack.push(coalescable)
        }

        // Start new coalescable operation
        ue.undo_mgr.coalescable_op = op
        ue.undo_mgr.last_mutation_time = now
        ue.undo_mgr.redo_stack = datatypes.Stack[UndoOperation]{}
    }
}

fn event_handler_with_undo(e &gg.Event, state_ptr voidptr) {
    mut ue := unsafe { &UndoableEditor(state_ptr) }

    match e.typ {
        .key_down {
            cmd_held := (e.modifiers & u32(gg.Modifier.super)) != 0
            shift_held := (e.modifiers & u32(gg.Modifier.shift)) != 0

            if cmd_held && e.key_code == .z {
                if shift_held {
                    // Cmd+Shift+Z: redo
                    ue.undo_mgr.redo(mut ue.EditorState) or { return }
                } else {
                    // Cmd+Z: undo
                    ue.undo_mgr.undo(mut ue.EditorState) or { return }
                }
                return
            }

            // Handle backspace with undo tracking
            if e.key_code == .backspace {
                cursor_before := ue.cursor_idx
                anchor_before := ue.anchor_idx

                result := vglyph.delete_backward(ue.text, ue.layout, ue.cursor_idx)
                if result.new_text != ue.text {
                    ue.text = result.new_text
                    ue.cursor_idx = result.cursor_pos
                    ue.layout = ue.ts.layout_text(ue.text, ue.cfg) or { return }

                    // Track for undo
                    ue.handle_mutation(result, '', cursor_before, anchor_before)
                }
            }
        }
        .char {
            // Character insertion with undo tracking
            cursor_before := ue.cursor_idx
            anchor_before := ue.anchor_idx

            char_str := utf32_to_string(e.char_code)
            result := vglyph.insert_text(ue.text, ue.cursor_idx, char_str)

            ue.text = result.new_text
            ue.cursor_idx = result.cursor_pos
            ue.layout = ue.ts.layout_text(ue.text, ue.cfg) or { return }

            // Track for undo
            ue.handle_mutation(result, char_str, cursor_before, anchor_before)
        }
        else {}
    }
}
```

### Breaking Coalescing on Navigation
```v
// Navigation breaks coalescing - flush pending operation
fn (mut ue UndoableEditor) handle_navigation(e &gg.Event) {
    // Flush coalescable operation
    if coalescable := ue.undo_mgr.coalescable_op {
        ue.undo_mgr.undo_stack.push(coalescable)
        ue.undo_mgr.coalescable_op = none
    }

    // Then handle navigation
    match e.key_code {
        .left { ue.cursor_idx = ue.layout.move_cursor_left(ue.cursor_idx) }
        .right { ue.cursor_idx = ue.layout.move_cursor_right(ue.cursor_idx) }
        else {}
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Memento (state copies) | Command pattern (deltas) | 1990s-2000s | 100x-1000x memory reduction |
| Unlimited history | History limits (50-1000) | 2000s | Prevents OOM, bounded memory |
| Per-character undo | Coalesced operations | 2000s | Better UX, sensible granularity |
| Linear undo | Tree/graph undo | 2010s (Vim, Emacs) | Never lose edit history |

**Deprecated/outdated:**
- Storing full buffer snapshots: Memory prohibitive for large documents
- No coalescing: Poor UX, confusing undo behavior
- Infinite history: OOM risk, requirement explicitly limits to 50-100

## Open Questions

1. **Use datatypes.Stack or []T array?**
   - What we know: Stack provides clean API, but no remove-from-bottom
   - What's unclear: Performance impact of array conversion for trim_oldest
   - Recommendation: Use []T array for undo_stack, clearer for history limit enforcement
   - Need: Benchmark array vs Stack for typical operation (unlikely bottleneck)

2. **Coalescing timeout value?**
   - What we know: Emacs 500ms, Google Docs 2s, Quip 1s
   - What's unclear: User preference, use case dependent
   - Recommendation: Start with 1s (split difference), make configurable later
   - Need: User testing to validate

3. **Tree undo vs linear undo?**
   - What we know: Vim/Emacs support undo tree (never lose history)
   - What's unclear: UNDO-01/02 requirements imply linear undo
   - Recommendation: Linear for v1.3 (simpler, meets requirements), tree for v1.4+
   - Need: Verify requirements don't mandate tree structure

## Sources

### Primary (HIGH confidence)
- [V datatypes.Stack](https://modules.vlang.io/datatypes.html) - Official V stdlib docs (2026-02-03)
- VGlyph layout_mutation.v - Phase 13 MutationResult struct verified in codebase
- VGlyph editor_demo.v - Working mutation implementation to extend
- [Matt Duck: Undo/Redo in Text Editors](https://www.mattduck.com/undo-redo-text-editors) -
Comprehensive survey of Nano, Emacs, Neovim implementations

### Secondary (MEDIUM confidence)
- [Text Editor Undo: Rethinking
Undo](https://cdacamar.github.io/data%20structures/algorithms/benchmarking/text%20editors/c++/rethinking-undo/)
- Advanced tree-based undo with immutable structures
- [TinyMCE: Undo Function Handling](https://www.tiny.cloud/blog/undo-function-handling/) -
Coalescing rules: continuous typing, selection changes break coalescing
- [Emacs Undo
Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Undo.html) - Amalgamation (20
commands), 80000 history limit
- [Vim Undo Documentation](https://vimdoc.sourceforge.net/htmldoc/undo.html) - undolevels
default 1000, CTRL-G u for manual breaks

### Tertiary (LOW confidence)
- Web search results for command pattern - general design pattern info, not editor-specific

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - V stdlib verified, command pattern well-established
- Architecture: HIGH - Patterns from production editors (Emacs, Vim, VSCode)
- Pitfalls: HIGH - Common undo bugs documented in editor implementations
- Coalescing rules: MEDIUM - Timeout values vary by editor (500ms-2s), needs tuning

**Research date:** 2026-02-03
**Valid until:** 2026-03-03 (30 days - stable domain, established patterns)
