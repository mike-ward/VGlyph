# External Integrations

**Analysis Date:** 2026-02-01

## APIs & External Services

**Graphics APIs:**
- **Sokol Graphics (sg)** - GPU graphics abstraction
  - SDK/Client: Sokol library via `sokol.gfx`
  - Used in: `glyph_atlas.v`, `renderer.v`
  - Purpose: GPU texture management, sampler creation, graphics state
  - Integration: `app.ts.commit()` uploads glyph atlas to GPU each frame

**Display & Window Management:**
- **Sokol App (sapp)** - Window and event handling
  - SDK/Client: `sokol.sapp` module
  - Used in: `api.v` (DPI scaling), examples
  - Integration: `sapp.dpi_scale()` for high-DPI awareness

**Graphics Library:**
- **gg (V Graphics)** - 2D graphics context and rendering
  - SDK/Client: `gg` module
  - Used in: `api.v`, `glyph_atlas.v`, `renderer.v`, all examples
  - Purpose: Window creation, event loop, 2D drawing primitives
  - Integration: `gg.new_context()` creates main graphics context, `gg.Context`
    passed to `TextSystem`

## Data Storage

**Databases:**
- None - VGlyph is a text rendering library with no database integration

**File Storage:**
- **Local filesystem only** - Font file loading via system paths
  - Font discovery: `~/.ttf` / `~/.otf` files via FontConfig
  - macOS paths: `/System/Library/Fonts`, `/Library/Fonts`, `$HOME/Library/Fonts`
  - Linux: `/usr/share/fonts/` and other system paths (automatic via FontConfig)
  - Windows: System font registry (automatic via FontConfig)
  - No remote font CDN integration

**In-Memory Caching:**
- **Layout Cache:** `TextSystem.cache` - LRU cache with 10,000 entry limit
  - Stores `CachedLayout` objects indexed by u64 hash
  - `eviction_age: 5000ms` - Auto-prune stale entries
  - Location: `api.v` lines 17-24
- **Glyph Cache:** `Renderer.cache` - GPU glyph bitmap cache
  - Stores `CachedGlyph` entries
  - Location: `renderer.v` line 21
- **Atlas Storage:** `GlyphAtlas` - GPU texture holding rasterized glyphs
  - Default: 1024x1024 pixels, resizable
  - Location: `glyph_atlas.v`

## Authentication & Identity

**Auth Provider:**
- None - VGlyph has no authentication, identity, or user management

## Monitoring & Observability

**Error Tracking:**
- None - No integration with Sentry, Rollbar, or similar services

**Logs:**
- **V logging module** - Standard output
  - Used in: `context.v` (FreeType init errors), `glyph_atlas.v` (atlas resizing)
  - Pattern: `log.error()`, `log.debug()` for diagnostic messages
  - Example: `log.error('${@FILE_LINE}: Failed to initialize FreeType library')`
    in `context.v` line 27

**Metrics/Telemetry:**
- None - No production telemetry integration

## CI/CD & Deployment

**Hosting:**
- Not applicable - VGlyph is a library module, not a deployed service
- Compiled into host applications via V module system

**CI Pipeline:**
- Not detected in codebase
- Examples and tests compiled manually with V compiler

**Build Artifacts:**
- `.dylib` (macOS), `.so` (Linux), `.dll` (Windows) library binaries
- Pre-built example binaries in `examples/` directory

## Environment Configuration

**Required env vars:**
- None enforced by VGlyph itself

**Platform-Specific Env:**
- `HOME` - Used on macOS to resolve user font directory
  - Read in: `context.v` line 61
  - Example: `${HOME}/Library/Fonts` for user-installed fonts

**Font Configuration:**
- FontConfig (`FcConfig`) - System-wide font database
  - Auto-initialized: `C.FcInitLoadConfigAndFonts()` on macOS
  - Registered paths: `/System/Library/Fonts`, `/Library/Fonts`, user fonts
  - No environment variables required (automatic discovery)

**DPI/Scaling:**
- Detected at runtime: `sapp.dpi_scale()` returns platform DPI scale factor
- Resolution set in Pango context: `pango_ft2_font_map_set_resolution()`
- No config file required

## Webhooks & Callbacks

**Incoming Webhooks:**
- None - VGlyph is a synchronous library with no inbound event handlers

**Outgoing Webhooks:**
- None - No outbound HTTP/API calls

**Callbacks:**
- **Event handlers** - Application-provided callbacks
  - Pattern: `frame_fn`, `init_fn`, `event_fn` in `gg.new_context()`
  - Example: `examples/demo.v` lines 30-33 provide frame and event callbacks
- **Accessibility callbacks** - Custom VoiceOver integration
  - Objective-C message sends for macOS accessibility tree updates
  - Location: `accessibility/backend_darwin.v`

## Font/System Integration

**System Font Access:**
- **FontConfig** - Automatic font database access (all platforms)
  - Provides font fallback chain for unspecified fonts
  - Used: Emoji, multilingual (Arabic, Hebrew, CJK, etc.) character coverage
  - No API key or auth required - OS-level access

**Platform-Specific:**
- **macOS VoiceOver** - Accessibility integration via Objective-C
  - NSAccessibilityElement bridging
  - Optional: `TextSystem.enable_accessibility()` for screen reader support
  - Used in: `api.v`, `layout_accessibility.v`
  - Bindings: `accessibility/objc_bindings_darwin.v`

**GPU Integration:**
- **Sokol Graphics (Direct)** - GPU texture upload and sampling
  - `glyph_atlas.v` creates texture via `sg.make_image()`
  - Glyph rendering batched through `gg` drawing API
  - No separate GPU memory management required

## Data Formats Consumed

**Input:**
- **Font files:** `.ttf`, `.otf` (OpenType/TrueType)
  - Parsed by FreeType + FontConfig (C libraries)
- **Text markup:** Pango markup language (HTML-like tags)
  - Example: `<span foreground="blue" size="x-large">Large blue text</span>`
  - Used in: `examples/demo.v` lines 85-97, `api.v`
  - RFC: Pango Markup Language

**Output:**
- **GPU textures:** Rasterized glyph atlas (internal)
- **Layout metadata:** Character positions, bounding boxes, line breaks
  - No external format - purely in-memory V structs

## Real-World Integration Example

```v
// From examples/demo.v: Minimal VGlyph integration
import gg
import vglyph

fn main() {
    app := &App{
        gg: gg.new_context(
            width: 800, height: 600,
            frame_fn: frame,
            init_fn: init,
            user_data: app
        )
    }
    app.gg.run()  // Sokol app main loop
}

fn init(mut app App) {
    app.ts = vglyph.new_text_system(mut app.gg) or { panic(err) }
    // Pango + FreeType auto-initialized here
}

fn frame(mut app App) {
    app.gg.begin()
    app.ts.draw_text(10, 10, 'Hello', vglyph.TextConfig{})
    app.gg.end()
    app.ts.commit()  // GPU texture upload
}
```

---

*Integration audit: 2026-02-01*
