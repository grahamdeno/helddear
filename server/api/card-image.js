// GET /api/card-image?u=…: kept for older app builds (Nov 25, 2026: new card lists use /_vercel/image).
// A card picture from Handwrytten, served through Held Dear's own server (M6, Nov 24, 2026),
// so the phone only ever talks to Held Dear. Only Handwrytten's card image host is allowed; anything else is refused,
// so this can't be used to fetch other sites. Pictures are cached for a day.
export const IMAGE_HOST = "d3e924qpzqov0g.cloudfront.net";

export function allowedImage(raw) {
  try {
    const u = new URL(String(raw ?? ""));
    return u.protocol === "https:" && u.hostname === IMAGE_HOST && /^\/cardimages\//.test(u.pathname) ? u : null;
  } catch { return null; }
}

export default async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).json({ error: "Method not allowed" });
  const u = allowedImage(req.query?.u);
  if (!u) return res.status(400).json({ error: "Not a card picture" });
  try {
    const r = await fetch(u, { headers: { Accept: "image/*" } });
    // CloudFront often labels these files binary/octet-stream, so the type comes from the file name.
    const byName = { png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", webp: "image/webp", gif: "image/gif" };
    const type = byName[(u.pathname.split(".").pop() || "").toLowerCase()];
    if (!r.ok || !type) return res.status(502).json({ error: "Picture unavailable" });
    const body = Buffer.from(await r.arrayBuffer());
    // A function's reply must stay under 4.5 MB; larger pictures go through /_vercel/image instead.
    if (body.length > 4_000_000) return res.status(502).json({ error: "Picture too large" });
    res.setHeader("Content-Type", type);
    res.setHeader("Cache-Control", "public, max-age=86400, s-maxage=604800");
    res.setHeader("X-Content-Type-Options", "nosniff");
    return res.status(200).send(body);
  } catch (e) {
    console.error("card image failed:", e.message);
    return res.status(502).json({ error: "Picture unavailable" });
  }
}
