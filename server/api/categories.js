import { hw, pickList, isPersonal } from "../lib/handwrytten.js";

// GET /api/categories: Handwrytten's public card categories and how many personal cards each has, to tune which
// categories the app shows. No user data.
export default async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).json({ error: "Method not allowed" });
  try {
    const cats = pickList(await hw("/categories/list"), "categories", "data", "items");
    const out = [];
    for (const c of cats.slice(0, 60)) {
      let count = 0;
      try {
        const cards = pickList(await hw(`/cards/list?category_id=${c.id}&with_images=1`), "cards", "data", "items");
        count = cards.filter((x) => x.cover && x.id && isPersonal(x.name)).length;
      } catch {}
      out.push({ id: c.id, name: c.name, count });
    }
    return res.status(200).json({ categories: out });
  } catch (e) {
    return res.status(502).json({ error: "unavailable" });
  }
}
