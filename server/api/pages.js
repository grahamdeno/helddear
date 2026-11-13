import { blobStore, baseURL } from "../lib/blobstore.js";
import { createPage, deletePage, ownerView } from "../lib/pages.js";

// POST /api/pages: create a family page. GET ?id&key: the owner's view with notes. DELETE ?id&key: remove it all.
export default async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");
  try {
    let r;
    if (req.method === "POST") r = await createPage(blobStore, req.body ?? {}, baseURL());
    else if (req.method === "GET") r = await ownerView(blobStore, req.query.id, req.query.key);
    else if (req.method === "DELETE") r = await deletePage(blobStore, req.query.id, req.query.key);
    else r = { status: 405, body: { error: "Method not allowed" } };
    return res.status(r.status).json(r.body);
  } catch (e) {
    console.error("pages failed:", e.message);
    return res.status(502).json({ error: "Something went wrong. Try again in a little while." });
  }
}
