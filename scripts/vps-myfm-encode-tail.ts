/** Detect common raster containers by magic bytes (ignore misleading extensions). */
export function looksLikeRasterBuffer(buf: Buffer, extHint = ""): boolean {
  if (!buf || buf.length < 12) return false;
  const ext = extHint.toLowerCase();
  if (
    [".jpg", ".jpeg", ".png", ".webp", ".tif", ".tiff", ".heic", ".heif", ".gif", ".avif"].includes(
      ext,
    )
  ) {
    return true;
  }
  // JPEG
  if (buf[0] === 0xff && buf[1] === 0xd8) return true;
  // PNG
  if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) return true;
  // GIF
  if (buf[0] === 0x47 && buf[1] === 0x49 && buf[2] === 0x46) return true;
  // WEBP: RIFF....WEBP
  if (
    buf[0] === 0x52 &&
    buf[1] === 0x49 &&
    buf[2] === 0x46 &&
    buf[3] === 0x46 &&
    buf[8] === 0x57 &&
    buf[9] === 0x45 &&
    buf[10] === 0x42 &&
    buf[11] === 0x50
  ) {
    return true;
  }
  // TIFF
  if (
    (buf[0] === 0x49 && buf[1] === 0x49 && buf[2] === 0x2a && buf[3] === 0x00) ||
    (buf[0] === 0x4d && buf[1] === 0x4d && buf[2] === 0x00 && buf[3] === 0x2a)
  ) {
    return true;
  }
  // HEIC / HEIF / AVIF (ISO BMFF ftyp)
  if (buf.length >= 12 && buf[4] === 0x66 && buf[5] === 0x74 && buf[6] === 0x79 && buf[7] === 0x70) {
    const brand = buf.subarray(8, 12).toString("ascii");
    if (["heic", "heix", "hevc", "hevx", "mif1", "msf1", "avif", "avis"].includes(brand)) {
      return true;
    }
  }
  return false;
}

async function decodeHeicToJpeg(buf: Buffer): Promise<Buffer> {
  // Apple HEIC is often missing from sharp's bundled libheif codecs — use heic-convert.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const convert = require("heic-convert") as (opts: {
    buffer: Buffer;
    format: "JPEG" | "PNG";
    quality: number;
  }) => Promise<ArrayBuffer>;
  const out = await convert({ buffer: buf, format: "JPEG", quality: 0.92 });
  return Buffer.from(out);
}

/**
 * Normalize ANY upload (HEIC / P3 PNG / WebP / TIFF / JPEG) to sRGB JPEG bytes.
 * Empty uploads fail fast with a clear error (common iOS Limited Photos / iCloud stub).
 */
export async function normalizeUploadToSrgbJpeg(input: string | Buffer): Promise<Buffer> {
  const buf = typeof input === "string" ? await fs.readFile(input) : input;
  if (!buf.length) {
    throw new Error(
      "empty_image_upload: received 0 bytes (iCloud/Limited Photos stub or failed client read)",
    );
  }

  const trySharp = async (source: Buffer): Promise<Buffer> => {
    return sharp(source, { failOn: "none", unlimited: true })
      .rotate()
      .toColorspace("srgb")
      .flatten({ background: { r: 255, g: 255, b: 255 } })
      .jpeg({ quality: 92, mozjpeg: true })
      .toBuffer();
  };

  try {
    return await trySharp(buf);
  } catch (primary) {
    const msg = primary instanceof Error ? primary.message : String(primary);
    try {
      const jpegFromHeic = await decodeHeicToJpeg(buf);
      return await trySharp(jpegFromHeic);
    } catch (heicErr) {
      const heicMsg = heicErr instanceof Error ? heicErr.message : String(heicErr);
      throw new Error(`unsupported_image_format: sharp=${msg}; heic-convert=${heicMsg}`);
    }
  }
}

/** Raster → XT `.bin` sidecar next to upload (`<stem>.bin`) — only when client did not send `.bin`. */
export async function writeMyfmSidecar(uploadedAbsPath: string): Promise<string> {
  // Always decode → sRGB JPEG first so Display P3 / HEIC / WebP never hit the dither path raw.
  const jpegBuf = await normalizeUploadToSrgbJpeg(uploadedAbsPath);

  const stem = path.parse(uploadedAbsPath).name;
  const dir = path.dirname(uploadedAbsPath);
  const normJpegPath = path.join(dir, `${stem}.norm.jpg`);
  await fs.writeFile(normJpegPath, jpegBuf);

  const meta = await sharp(jpegBuf).metadata();
  const b = 128 * (1 - XT_CONTRAST);

  let pipeline = sharp(jpegBuf).rotate().resize(FRAME_W, FRAME_H, {
    fit: "cover",
    position: "centre",
    kernel: sharp.kernel.cubic,
  });
  if (meta.hasAlpha) {
    pipeline = pipeline.ensureAlpha().flatten({ background: { r: 255, g: 255, b: 255 } });
  }
  pipeline = pipeline
    .modulate({ brightness: XT_BRIGHTNESS, saturation: XT_SATURATION })
    .linear(XT_CONTRAST, b)
    .sharpen({ sigma: 1, m1: XT_SHARPNESS, m2: XT_SHARPNESS });

  const { data, info } = await pipeline.raw().toBuffer({ resolveWithObject: true });

  const ch = info.channels ?? 0;
  if (ch < 3) {
    throw new Error(`need at least 3 channels after processing, got ${ch}`);
  }
  const stride = ch;
  const out = encodeMyfmFromRgb(new Uint8Array(data), stride, info.width, info.height);

  const binPath = path.join(dir, `${stem}.bin`);
  await fs.writeFile(binPath, out);

  return `${stem}.bin`;
}
