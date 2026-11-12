import { listBirthdayCards, placeOrder } from "../lib/handwrytten.js";
import { charge, refund, tagOrder, tokenFromApplePay } from "../lib/stripe.js";
import { retailCents, validateOrder } from "../lib/validate.js";

// POST /api/order: pay with Apple Pay, then (and only then) mail the card.
// Names and addresses are used for this one order and never logged.
export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
  let cards;
  try {
    cards = await listBirthdayCards();
  } catch (e) {
    console.error("cards failed:", e.message);
    return res.status(502).json({ error: "Cards are unavailable right now. You weren't charged." });
  }
  const checked = validateOrder(req.body, cards);
  if (checked.error) return res.status(400).json({ error: checked.error });
  const o = checked.value;

  let payment;
  try {
    const token = await tokenFromApplePay(o.applePay);
    payment = await charge({ tokenId: token.id, amount: retailCents(), reference: o.reference,
                             description: `Held Dear mailed card ${o.card.id}` });
  } catch (e) {
    console.error("payment failed:", e.code ?? "", e.message);
    return res.status(402).json({ error: "The payment didn't go through. You weren't charged." });
  }
  if (payment.status !== "succeeded") {
    return res.status(402).json({ error: "The payment didn't go through. You weren't charged." });
  }

  try {
    const orderId = await placeOrder({ ...o, cardId: o.card.id });
    await tagOrder(payment.id, String(orderId ?? "")).catch(() => {});
    return res.status(200).json({ orderId, mailing: "Mailing within 2 business days" });
  } catch (e) {
    console.error("order failed:", e.message);
    await refund(payment.id, o.reference).catch((r) => console.error("refund failed:", r.message));
    return res.status(502).json({ error: "The card couldn't be placed, so the payment was refunded. Please try again later." });
  }
}
