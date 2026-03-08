#!/bin/sh
# Patch vendored sd/ sources for R package compatibility.
#
# C++ <cstdio> does '#undef printf', so the r_ggml_compat.h macro approach
# does not work for .cpp/.hpp files.  Instead we do direct text replacements.
#
# Usage:  ./tools/patch_sd_sources.sh [src_dir]
#   src_dir defaults to 'src/sd' (relative to package root).
#
# After updating upstream (git subtree pull), re-run this script.

SD_DIR="${1:-src/sd}"

if [ ! -d "$SD_DIR" ]; then
  echo "ERROR: directory '$SD_DIR' not found" >&2
  exit 1
fi

echo "* Patching sd/ sources for R compatibility..."

# --- 1. Replace printf/puts/fflush/putchar with R-safe wrappers ---
#
# We only patch active (non-commented) calls.
# sed expressions:
#   - Skip lines starting with optional whitespace + '//'
#   - Replace whole-word printf( -> r_ggml_printf(
#   - Replace whole-word puts( -> r_ggml_puts(
#   - Replace whole-word putchar( -> r_ggml_putchar(
#   - Replace fflush(stdout) -> r_ggml_fflush(NULL)
#   - Replace fflush(stderr) -> r_ggml_fflush(NULL)
#   - Do NOT touch snprintf, sprintf, fprintf, vprintf, log_printf

# Process all .cpp, .hpp, .h, .c files (excluding thirdparty/)
find "$SD_DIR" -maxdepth 1 \( -name '*.cpp' -o -name '*.hpp' -o -name '*.h' -o -name '*.c' \) | while read -r f; do
  # Skip already-patched files (idempotent)
  if grep -q 'r_ggml_printf' "$f" 2>/dev/null; then
    continue
  fi

  sed -i \
    -e '/^[[:space:]]*\/\//! s/\bprintf\b\s*(/r_ggml_printf(/g' \
    -e '/^[[:space:]]*\/\//! s/\bputs\b\s*(/r_ggml_puts(/g' \
    -e '/^[[:space:]]*\/\//! s/\bputchar\b\s*(/r_ggml_putchar(/g' \
    -e '/^[[:space:]]*\/\//! s/\bfflush\b\s*(stdout)/r_ggml_fflush(NULL)/g' \
    -e '/^[[:space:]]*\/\//! s/\bfflush\b\s*(stderr)/r_ggml_fflush(NULL)/g' \
    "$f"

  echo "  patched: $(basename "$f")"
done

# --- 2. Patch thirdparty/ separately (only specific files) ---
if [ -f "$SD_DIR/thirdparty/stb_image_resize.h" ]; then
  if ! grep -q 'r_ggml_printf' "$SD_DIR/thirdparty/stb_image_resize.h" 2>/dev/null; then
    sed -i \
      -e '/^[[:space:]]*\/\//! s/\bprintf\b\s*(/r_ggml_printf(/g' \
      "$SD_DIR/thirdparty/stb_image_resize.h"
    echo "  patched: thirdparty/stb_image_resize.h"
  fi
fi

echo "* Done."
