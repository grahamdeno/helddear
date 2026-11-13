import { blobStore } from "../lib/blobstore.js";
import { CSP, giftPage, gonePage, invitePage } from "../lib/html.js";
import { visitorView } from "../lib/pages.js";

// GET /p/:id/:k (family adds notes) and /g/:id/:k (the person's page), rewritten here by vercel.json.
export default async function handler(req, res) {
  res.setHeader("Content-Security-Policy", CSP);
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  const mode = req.query.mode === "gift" ? "gift" : "invite";
  try {
    const v = await visitorView(blobStore, mode, req.query.id, req.query.k);
    if (v.status !== 200) return res.status(v.status).send(gonePage(v.status));
    const html = mode === "gift"
      ? giftPage({ page: v.page, notes: v.notes })
      : invitePage({ page: v.page, count: v.count, id: req.query.id, key: req.query.k,
                     added: req.query.added === "1", error: req.query.error ? String(req.query.error).slice(0, 120) : null });
    return res.status(200).send(html);
  } catch (e) {
    console.error("page failed:", e.message);
    return res.status(502).send(gonePage(502));
  }
}
