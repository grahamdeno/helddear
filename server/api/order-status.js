import { findByReference } from "../lib/stripe.js";
import { pausedReply } from "../lib/switches.js";

// GET /api/order-status?reference=…: where one order stands, after a slow reply (M1, Nov 24, 2026).
// Answers only "none", "charged" (with the order number once placed) or "refunded"; nothing about the card or people.
export default async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");
  if (req.method !== "GET") return res.status(405).json({ error: "Method not allowed" });
  const paused = pausedReply();
  if (paused) return res.status(paused.status).json(paused.body);
  const reference = String(req.query?.reference ?? "");
  if (!/^[A-Za-z0-9-]{8,64}$/.test(reference)) return res.status(400).json({ error: "Bad reference" });
  try {
    const s = await findByReference(reference);
    return res.status(200).json({ state: s.state, orderId: s.orderId ?? null });
  } catch (e) {
    console.error("status failed:", e.message);
    return res.status(502).json({ error: "Can't check right now." });
  }
}
