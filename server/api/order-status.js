import { pausedReply } from "../lib/switches.js";
import { makeOrders, standingOf } from "../lib/orders.js";
import { isTestMode } from "../lib/stripe.js";

// GET /api/order-status?reference=…: where one order stands, after a slow reply (M1; Fable N1, Nov 25, 2026).
// Read from the order's own record, never Stripe's search. Answers none, pending, charged (with the order number once
// placed), refunded or attention; nothing about the card or the people.
export default async function handler(req, res) {
  const { blobStore } = await import("../lib/blobstore.js");
  return handle(req, res, { pausedReply, orders: makeOrders(blobStore, isTestMode() ? "test" : "live") });
}

export async function handle(req, res, d) {
  res.setHeader?.("Cache-Control", "no-store");
  if (req.method !== "GET") return res.status(405).json({ error: "Method not allowed" });
  const paused = d.pausedReply();
  if (paused) return res.status(paused.status).json(paused.body);
  const reference = String(req.query?.reference ?? "");
  if (!/^[A-Za-z0-9-]{8,64}$/.test(reference)) return res.status(400).json({ error: "Bad reference" });
  try {
    return res.status(200).json(standingOf(await d.orders.get(reference)));
  } catch (e) {
    console.error("status failed:", e.message);
    return res.status(502).json({ error: "Can't check right now." });
  }
}
