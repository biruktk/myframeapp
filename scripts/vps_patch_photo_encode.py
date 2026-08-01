#!/usr/bin/env python3
"""Patch /var/myframe/backend/src/routes/photo.ts for HEIC/empty-upload hardening."""
from pathlib import Path

p = Path("/var/myframe/backend/src/routes/photo.ts")
text = p.read_text()

old_imp = """import {
  assertXt13e6Bin,
  isProbablyMyfmBuffer,
  storeClientXtBin,
  writeMyfmSidecar,
  XT_BIN_TOTAL_BYTES,
} from \"../services/myfm_encode\";"""

new_imp = """import {
  assertXt13e6Bin,
  isProbablyMyfmBuffer,
  looksLikeRasterBuffer,
  storeClientXtBin,
  writeMyfmSidecar,
  XT_BIN_TOTAL_BYTES,
} from \"../services/myfm_encode\";"""

if old_imp not in text:
    raise SystemExit("import block not found")
text = text.replace(old_imp, new_imp, 1)

# Replace both identical looksLikeRaster definitions + encode try/catch blocks
# by a line-oriented approach around each occurrence.

needle = 'const looksLikeRaster =\n        [".jpg", ".jpeg", ".png", ".webp"].includes(ext) || (buf.length > 2 && buf[0] === 0xff && buf[1] === 0xd8);'
if text.count(needle) != 2:
    # try alternate formatting
    needle2 = 'const looksLikeRaster =\n        [".jpg", ".jpeg", ".png", ".webp"].includes(ext) || (buf.length > 2 && buf[0] === 0xff && buf[1] === 0xd8);'
    print("needle count", text.count(needle))
    # show nearby
    idx = text.find("const looksLikeRaster")
    print(repr(text[idx:idx+180]))
    raise SystemExit("looksLikeRaster needle mismatch")

text = text.replace(
    needle,
    "const looksLikeRaster = looksLikeRasterBuffer(buf, ext);",
)

# Insert empty-upload guard after imageProcessing init (both handlers)
guard_anchor = 'let imageProcessing: "client_passthrough" | "server_myfm_encode" | "stored_raw" = "stored_raw";\n\n      if (isProbablyMyfmBuffer(buf))'
guard_repl = '''let imageProcessing: "client_passthrough" | "server_myfm_encode" | "stored_raw" = "stored_raw";

      if (!buf.length) {
        res.status(400).json({
          ok: false,
          error: "empty_upload",
          message:
            "Uploaded file is empty (0 bytes). On iPhone: grant Full Photos access and wait for iCloud download, then retry.",
        });
        return;
      }

      if (isProbablyMyfmBuffer(buf))'''

if text.count(guard_anchor) != 2:
    raise SystemExit(f"guard anchor count={text.count(guard_anchor)}")
text = text.replace(guard_anchor, guard_repl)

old_catch = '''        } catch (err) {
          const detail = err instanceof Error ? err.message : String(err);
          console.error("[photo] MYFM encode failed:", detail);
          res.status(503).json({
            ok: false,
            error: "myfm_encode_failed",
            message: detail,
            hint:
              "XT ePaper / ESP32 only renders MYFM .bin. Fix sharp/libvips on the server, ensure FRAME_MYFM_ENCODE=1, and rebuild. JPEG/PNG is never sent to MQTT.",
          });
          return;
        }'''

new_catch = '''        } catch (err) {
          const detail = err instanceof Error ? err.message : String(err);
          console.error("[photo] MYFM encode failed:", detail);
          const empty = detail.includes("empty_image_upload");
          res.status(empty ? 400 : 503).json({
            ok: false,
            error: empty ? "empty_upload" : "myfm_encode_failed",
            message: detail,
            hint: empty
              ? "iPhone sent 0 bytes — Full Photos access + fully downloaded photo required."
              : "Server normalizes HEIC/PNG/WebP to sRGB JPEG then encodes XT .bin. If this persists, the file may be corrupt.",
          });
          return;
        }'''

if text.count(old_catch) != 2:
    raise SystemExit(f"catch block count={text.count(old_catch)}")
text = text.replace(old_catch, new_catch)

p.write_text(text)
print("photo.ts patched successfully")
