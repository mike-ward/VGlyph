# Technology Stack

**Analysis Date:** 2026-02-01

## Languages

**Primary:**
- **V** - Latest stable - All core library code, module implementation, and C bindings

**Secondary:**
- **C/C++** - Via pkg-config - C library bindings (FreeType, Pango, HarfBuzz, etc.)
- **Objective-C** - macOS only - Accessibility layer for VoiceOver integration

## Runtime

**Environment:**
- V compiler (requires v0.4+ based on module structure)
- pkg-config - For locating and linking C libraries

**Package Manager:**
- V module system (`v.mod`)
- System package managers: Homebrew (macOS), apt-get (Linux), vcpkg/MSYS2 (Windows)

**Lockfile:**
- `v.mod`: Module manifest (no external V dependencies)

## Frameworks

**Core:**
- **Pango** - Text layout and shaping engine (primary Unicode/complex script support)
- **HarfBuzz** - OpenType shaping (via Pango integration)
- **FreeType** - Font rasterization and glyph rendering
- **FontConfig** - Font discovery and configuration (macOS)
- **GLib** - Object system (required by Pango)
- **GObject** - Pango object system integration

**Graphics:**
- **gg** - V graphics library (windowing, 2D rendering, event handling)
  - Location: `api.v`, `renderer.v`, examples
  - Purpose: Window management, event loop, 2D context
- **Sokol** - Low-level graphics abstraction
  - `sokol.gfx` (sg) - GPU/graphics backend (`glyph_atlas.v`, `renderer.v`)
  - `sokol.sgl` - Simple graphics library for debug rendering
  - `sokol.sapp` - App framework integration (DPI scaling via `sapp.dpi_scale()`)

**Accessibility:**
- **Accessibility module** - Custom V module for screen reader integration
  - `accessibility/` directory
  - macOS VoiceOver via Objective-C bindings (`accessibility/objc_bindings_darwin.v`)

## Key Dependencies

**Critical C Libraries:**
- `freetype2` - Font loading, glyph metrics, rendering
  - Used: `context.v`, `c_bindings.v`, glyph rasterization pipeline
  - Version: Via pkg-config (typically FreeType 2.x)
- `harfbuzz` - OpenType shaping for complex scripts
  - Used: Indirectly via Pango
  - Linked: `#pkgconfig harfbuzz` in `c_bindings.v`
- `pango` + `pangoft2` - Text layout with Unicode support
  - Used: All text layout operations (`layout.v`, `context.v`)
  - Core: `C.pango_layout_new()`, `C.pango_ft2_font_map_new()`
- `glib-2.0` + `gobject-2.0` - Object system
  - Used: Pango object lifecycle management (`context.v`)
- `fontconfig` - Font resolution and fallback
  - Used: Font discovery, system font registration (`context.v`)
- `fribidi` - Bidirectional text support
  - Used: Arabic, Hebrew text handling (via Pango)
  - Linked: `#pkgconfig fribidi` in `c_bindings.v`

**Infrastructure:**
- Standard V libs: `log`, `os`, `time`, `math`, `strings`
  - Used: Logging (`context.v`, `glyph_atlas.v`), file I/O, timing, calculations

## Configuration

**Environment:**
- **DPI Scaling:** `sokol.sapp.dpi_scale()` - Auto-detected at runtime
- **Platform Detection:** V's `$if` conditional compilation
  - `$if macos` - macOS-specific font dir registration in `context.v`
  - Platform-specific accessibility backends in `accessibility/`

**Build:**
- C Flags: `#flag -I@VMODROOT`, `-I@VEXEROOT/thirdparty/freetype/include`
- pkg-config used for: freetype2, harfbuzz, pango, pangoft2, gobject-2.0, glib-2.0,
  fontconfig, fribidi
- Compilation: V compiler handles C interop and native code generation

**Font Configuration:**
- System fonts auto-registered on macOS via FontConfig (`context.v` lines 51-69)
- User fonts loaded from `$HOME/Library/Fonts` (macOS)
- System paths: `/System/Library/Fonts`, `/Library/Fonts` (macOS)

## Platform Requirements

**Development:**
- V compiler (0.4+)
- macOS: `brew install pango freetype pkg-config`
- Linux: `sudo apt-get install libpango1.0-dev libfreetype6-dev pkg-config`
  - Optional: `fonts-noto fonts-noto-color-emoji` for full multilingual support
- Windows: `vcpkg install pango freetype` or MSYS2 pacman equivalents

**Runtime:**
- System fonts installed (OS-dependent)
- Pango + FreeType + HarfBuzz shared libraries loaded at runtime
- Font fallback requires fonts-noto or equivalent for emoji/CJK coverage

**Produced Artifacts:**
- `.dylib` (macOS) - Compiled VGlyph module library
- `.so` (Linux) - Shared object
- `.dll` (Windows) - Dynamic link library
- Examples compile to executable binaries

---

*Stack analysis: 2026-02-01*
