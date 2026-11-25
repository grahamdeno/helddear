import { listCards, OCCASION_CATEGORY, placeOrder } from "../lib/handwrytten.js";
import { charge, findByReference, markRefunded, refund, tagOrder, tokenFromApplePay } from "../lib/stripe.js";
import { retailCents, validateOrder } from "../lib/validate.js";
import { isTestMode } from "../lib/stripe.js";
import { pausedReply } from "../lib/switches.js";

const real = { listCards, placeOrder, charge, refund, tagOrder, tokenFromApplePay, isTestMode, pausedReply, findByReference, markRefunded };

// POST /api/order: pay with Apple Pay, then (and only then) mail the card.
// Names and addresses are used for this one order and never logged.
// With Stripe test keys, nothing is ever sent to Handwrytten: the order is checked and a test order number comes
// back (M2, Nov 24, 2026), so the whole flow can be tried without mailing a real card.
export default function handler(req, res) { return handle(req, res, real); }

export async function handle(req, res, d) {
  const { listCards, placeOrder, charge, refund, tagOrder, tokenFromApplePay } = d;
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
  const paused = d.pausedReply();
  if (paused) return res.status(paused.status).json(paused.body);
  let cards;
  try {
    const raw = String(req.body?.occasion ?? "birthday");
    cards = await listCards(Object.hasOwn(OCCASION_CATEGORY, raw) ? raw : "birthday");
  } catch (e) {
    console.error("cards failed:", e.message);
    return res.status(502).json({ error: "Cards are unavailable right now. You weren't charged." });
  }
  const checked = validateOrder(req.body, cards);
  if (checked.error) return res.status(400).json({ error: checked.error });
  const o = checked.value;

  // A retry with the same reference never charges or mails twice (M1): if this order was already paid, answer with
  // where it stands.
  try {
    const before = await d.findByReference(o.reference);
    if (before.state === "charged" && before.orderId) {
      return res.status(200).json({ orderId: Number(before.orderId) || before.orderId, mailing: "Mailing within 3 business days", repeat: true });
    }
    if (before.state === "refunded") {
      return res.status(409).json({ error: "This order was refunded. Start a new card to try again.", refunded: true });
    }
  } catch (e) {
    console.error("lookup failed:", e.message);
    return res.status(502).json({ error: "Payments can't be checked right now. You weren't charged. Try again in a little while." });
  }

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

  if (d.isTestMode()) {
    return res.status(200).json({ orderId: `test-${o.reference}`, mailing: "Test order: nothing was mailed", test: true });
  }

  try {
    const orderId = await placeOrder({ ...o, cardId: o.card.id });
    await tagOrder(payment.id, String(orderId ?? "")).catch(() => {});
    return res.status(200).json({ orderId, mailing: "Mailing within 3 business days" });
  } catch (e) {
    console.error("order failed:", e.message);
    await refund(payment.id, o.reference)
      .then(() => d.markRefunded(payment.id).catch(() => {}))
      .catch((r) => console.error("refund failed:", r.message));
    return res.status(502).json({ error: "The card couldn't be placed, so the payment was refunded. Please try again later.", refunded: true });
  }
}
