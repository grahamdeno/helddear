import { listBirthdayCards } from "../lib/handwrytten.js";
import { retailCents } from "../lib/validate.js";
import { isTestMode } from "../lib/stripe.js";

// GET /api/cards: Handwrytten's birthday cards and the one price for a mailed card.
export default async function handler(req, res) {
  if (req.method !== "GET") return res.status(405).json({ error: "Method not allowed" });
  try {
    const cards = await listBirthdayCards();
    res.setHeader("Cache-Control", "s-maxage=3600, stale-while-revalidate=86400");
    return res.status(200).json({ cards, priceCents: retailCents(), currency: "usd", testMode: isTestMode() });
  } catch (e) {
    console.error("cards failed:", e.message);
    return res.status(502).json({ error: "Cards are unavailable right now. Try again in a little while." });
  }
}
