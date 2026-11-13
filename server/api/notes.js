import { blobStore } from "../lib/blobstore.js";
import { addNote, removeNote } from "../lib/pages.js";

// POST /api/notes: family adds a note (HTML form or JSON). DELETE ?id&key&note: the owner removes one.
export default async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");
  try {
    if (req.method === "DELETE") {
      const r = await removeNote(blobStore, req.query.id, req.query.key, req.query.note);
      return res.status(r.status).json(r.body);
    }
    if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
    const body = req.body ?? {};
    const r = await addNote(blobStore, body);
    const fromForm = !String(req.headers["content-type"] ?? "").includes("application/json");
    if (fromForm && /^[A-Za-z0-9_-]{16,32}$/.test(String(body.id)) && /^[A-Za-z0-9_-]{16,32}$/.test(String(body.k))) {
      const q = r.status === 200 ? "added=1" : `error=${encodeURIComponent(r.body.error ?? "Something went wrong")}`;
      res.setHeader("Location", `/p/${body.id}/${body.k}?${q}`);
      return res.status(303).end();
    }
    return res.status(r.status).json(r.body);
  } catch (e) {
    console.error("notes failed:", e.message);
    return res.status(502).json({ error: "Something went wrong. Try again in a little while." });
  }
}
