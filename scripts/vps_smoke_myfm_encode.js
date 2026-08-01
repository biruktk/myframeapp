const path = require("path");
const fs = require("fs");
const {
  writeMyfmSidecar,
  normalizeUploadToSrgbJpeg,
  looksLikeRasterBuffer,
} = require("/var/myframe/backend/dist/services/myfm_encode");

(async () => {
  const uploads = "/var/myframe/backend/uploads";
  const sample = fs
    .readdirSync(uploads)
    .find((f) => f.endsWith(".jpg") && fs.statSync(path.join(uploads, f)).size > 1000);
  if (!sample) throw new Error("no sample jpg");
  const src = path.join(uploads, sample);
  const buf = fs.readFileSync(src);
  console.log("looksLikeRaster", looksLikeRasterBuffer(buf, ".jpg"));
  const jpeg = await normalizeUploadToSrgbJpeg(src);
  console.log("normalized jpeg bytes", jpeg.length, "magic", jpeg[0].toString(16), jpeg[1].toString(16));

  const tmp = path.join(uploads, `smoke_${Date.now()}.jpg`);
  fs.copyFileSync(src, tmp);
  const bin = await writeMyfmSidecar(tmp);
  const binPath = path.join(uploads, bin);
  console.log("bin", bin, "size", fs.statSync(binPath).size);

  const empty = path.join(uploads, `empty_smoke_${Date.now()}.jpg`);
  fs.writeFileSync(empty, Buffer.alloc(0));
  try {
    await writeMyfmSidecar(empty);
    console.log("EMPTY UNEXPECTED OK");
  } catch (e) {
    console.log("empty ok:", String(e.message).slice(0, 100));
  }

  const png = fs
    .readdirSync(uploads)
    .find((f) => f.toLowerCase().endsWith(".png") && fs.statSync(path.join(uploads, f)).size > 1000);
  if (png) {
    const p = path.join(uploads, `smoke_png_${Date.now()}.png`);
    fs.copyFileSync(path.join(uploads, png), p);
    const b2 = await writeMyfmSidecar(p);
    console.log("png->bin", b2, fs.statSync(path.join(uploads, b2)).size);
  }
  console.log("SMOKE_OK");
})().catch((e) => {
  console.error("SMOKE_FAIL", e);
  process.exit(1);
});
