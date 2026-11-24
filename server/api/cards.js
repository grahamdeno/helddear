import { listCards, listMoreCards, listSections, ownSection, OCCASION_CATEGORY } from "../lib/handwrytten.js";
import { retailCents } from "../lib/validate.js";
import { isTestMode } from "../lib/stripe.js";
import { pausedReply } from "../lib/switches.js";

// GET /api/cards?occasion=anniversary: Handwrytten's cards for that occasion (birthday by default) and the one price.
// Also every personal category with its cards ("sections") and the occasion's own category name ("own"), for the
// app's category menu and search (Nov 22, 2026). Apps before that ignore both.
export default async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).json({ error: "Method not allowed" });
  const paused = pausedReply();
  if (paused) return res.status(paused.status).json(paused.body);
  try {
    const raw = String(req.query?.occasion ?? "birthday");
    const occasion = Object.hasOwn(OCCASION_CATEGORY, raw) ? raw : "birthday";
    const cards = await listCards(occasion);
    const more = await listMoreCards(occasion, cards.map((c) => c.id)).catch(() => []);
    const [sections, own] = await Promise.all([listSections().catch(() => []), ownSection(occasion)]);
    res.setHeader("Cache-Control", "s-maxage=3600, stale-while-revalidate=86400");
    return res.status(200).json({ cards, more, sections, own, priceCents: retailCents(), currency: "usd", testMode: isTestMode() });
  } catch (e) {
    console.error("cards failed:", e.message);
    return res.status(502).json({ error: "Cards are unavailable right now. Try again in a little while." });
  }
}
