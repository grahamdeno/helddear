import { OCCASION_CATEGORY, pickerCards, placeOrder } from "../lib/handwrytten.js";
import { alreadyPaying, charge, isTestMode, refund, tagOrder, tokenFromApplePay } from "../lib/stripe.js";
import { overDailyLimit, readsAsThreat } from "../lib/limits.js";
import { retailCents, validateOrder } from "../lib/validate.js";
import { pausedReply } from "../lib/switches.js";
import { makeOrders } from "../lib/orders.js";

const SUPPORT = "support@tangomike.app";
const MAILING = "Mailing within 3 business days";

// Blob storage loads only when the server runs, so tests need no network package.
const real = async () => {
  const { blobStore } = await import("../lib/blobstore.js");
  return {
    pickerCards, placeOrder, charge, refund, tagOrder, tokenFromApplePay, isTestMode, pausedReply,
    orders: makeOrders(blobStore, isTestMode() ? "test" : "live"),
  };
};

// POST /api/order: pay with Apple Pay, then (and only then) mail the card.
// Names, addresses and the message are used for this one order and never logged or kept here. A record per
// reference (lib/orders.js) is written before the charge, so a retry never charges or mails twice (Fable N1, N2).
// With Stripe test keys, nothing is ever sent to Handwrytten (M2).
export default async function handler(req, res) { return handle(req, res, await real()); }

export async function handle(req, res, d) {
  const { orders } = d;
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
  const paused = d.pausedReply();
  if (paused) return res.status(paused.status).json(paused.body);

  // Everything that can be checked without Handwrytten, first (N9).
  const first = validateOrder(req.body);
  if (first.error) return res.status(400).json({ error: first.error });
  const reference = first.value.reference;

  // A message that reads as a threat is never mailed (M8).
  if (readsAsThreat(first.value.message, first.value.wishes)) {
    return res.status(400).json({ error: "This message can't be mailed. Please change it and try again. You weren't charged." });
  }

  // Where this reference already stands, from its own record (N1).
  let rec;
  try {
    rec = await orders.get(reference);
  } catch (e) {
    console.error("order record read failed:", e.message);
    return res.status(502).json({ error: "Payments can't be checked right now. You weren't charged. Try again in a little while." });
  }
  if (rec?.state === "placed") {
    return res.status(200).json({ orderId: rec.orderNumber, mailing: rec.test ? "Test order: nothing was mailed" : MAILING, repeat: true, test: rec.test || undefined });
  }
  if (rec?.state === "refunded") {
    return res.status(409).json({ error: "This order was refunded. Start a new card to try again.", refunded: true });
  }
  if (rec?.state === "attention") {
    return res.status(409).json({ error: `This order is being looked into. Nothing more will be charged. If you need help, write to ${SUPPORT}.`, attention: true });
  }

  // The card: one the picker can show (N5).
  let checked;
  try {
    const raw = String(req.body?.occasion ?? "birthday");
    const cards = await d.pickerCards(Object.hasOwn(OCCASION_CATEGORY, raw) ? raw : "birthday");
    checked = validateOrder(req.body, cards);
  } catch (e) {
    console.error("cards failed:", e.message);
    if (rec?.state === "charged" || rec?.state === "placing") return needsLook(res, orders, reference, "cards unavailable on retry");
    return res.status(502).json({ error: "Cards are unavailable right now. You weren't charged." });
  }
  if (checked.error) return res.status(400).json({ error: checked.error });
  const o = checked.value;

  // Paid before, with no order number (N2): never take a new token or charge again.
  if (rec?.state === "charged") return place(res, d, o, rec.paymentId);
  if (rec?.state === "placing") {
    // The last try may have reached Handwrytten. Placing again could mail two cards, so refund instead.
    return refundAndReply(res, d, o, rec.paymentId, "The card couldn't be confirmed, so the payment was refunded. Please try again later.");
  }

  let token;
  try {
    token = await d.tokenFromApplePay(o.applePay);
  } catch (e) {
    console.error("token failed:", e.message);
    return res.status(402).json({ error: "The payment didn't go through. You weren't charged." });
  }
  const cardPrint = token.card?.fingerprint ?? null;
  // The daily limit needs to know the payment card; without it, nothing is charged (N7).
  if (!cardPrint) return res.status(402).json({ error: "This payment card can't be used for mailed cards. Try another card. You weren't charged." });
  try {
    if (overDailyLimit(await orders.countToday(cardPrint))) {
      return res.status(429).json({ error: "That's the most cards one payment card can send in a day. Try again tomorrow. You weren't charged." });
    }
    await orders.put(reference, { state: "started", cardPrint });
    await orders.notePrint(cardPrint, reference);
  } catch (e) {
    console.error("order record write failed:", e.message);
    return res.status(502).json({ error: "Payments can't be checked right now. You weren't charged. Try again in a little while." });
  }

  let payment;
  try {
    payment = await d.charge({ tokenId: token.id, amount: retailCents(), reference,
                               description: `Held Dear mailed card ${o.card.id}`, cardPrint });
  } catch (e) {
    console.error("payment failed:", e.message);
    if (alreadyPaying(e) || e.timedOut) {
      // Stripe already has a charge for this reference, or didn't answer in time: it may have gone through.
      // Never call it declined (N2); the daily check settles it.
      return res.status(409).json({ error: "This payment is still being confirmed. Check again in a minute; you won't be charged twice.", pending: true });
    }
    await orders.put(reference, { state: "declined" }).catch(() => {});
    return res.status(402).json({ error: "The payment didn't go through. You weren't charged." });
  }
  if (payment.status !== "succeeded") {
    await orders.put(reference, { state: "declined" }).catch(() => {});
    return res.status(402).json({ error: "The payment didn't go through. You weren't charged." });
  }
  await orders.put(reference, { state: "charged", paymentId: payment.id }).catch((e) => console.error("order record write failed:", e.message));
  return place(res, d, o, payment.id);
}

/** Places a paid order, or refunds it if Handwrytten can't take it. */
async function place(res, d, o, paymentId) {
  const { orders } = d;
  if (d.isTestMode()) {
    const orderNumber = `test-${o.reference}`;
    await orders.put(o.reference, { state: "placed", orderNumber, test: true }).catch(() => {});
    return res.status(200).json({ orderId: orderNumber, mailing: "Test order: nothing was mailed", test: true });
  }
  try {
    await orders.put(o.reference, { state: "placing" });
  } catch (e) {
    console.error("order record write failed:", e.message);
    // Without the record, a retry couldn't tell this card was sent; refund rather than risk two.
    return refundAndReply(res, d, o, paymentId, "The card couldn't be placed, so the payment was refunded. Please try again later.");
  }
  try {
    const orderId = await d.placeOrder({ ...o, cardId: o.card.id });
    const orderNumber = orderId == null ? null : String(orderId);
    await orders.put(o.reference, { state: "placed", orderNumber }).catch((e) => console.error("order record write failed:", e.message));
    await d.tagOrder(paymentId, orderNumber ?? "").catch(() => {});
    return res.status(200).json({ orderId, mailing: MAILING });
  } catch (e) {
    console.error("order failed:", e.message);
    return refundAndReply(res, d, o, paymentId, "The card couldn't be placed, so the payment was refunded. Please try again later.");
  }
}

/** Refunds and says so only when the refund went through (N4). */
async function refundAndReply(res, d, o, paymentId, words) {
  try {
    await d.refund(paymentId, o.reference);
  } catch (e) {
    console.error("refund failed:", e.message);
    return needsLook(res, d.orders, o.reference, "refund failed");
  }
  await d.orders.put(o.reference, { state: "refunded" }).catch((e) => console.error("order record write failed:", e.message));
  return res.status(502).json({ error: words, refunded: true });
}

/** Marks the order for the daily check and tells the person the truth: it's being handled. */
async function needsLook(res, orders, reference, why) {
  await orders.put(reference, { state: "attention", why }).catch((e) => console.error("order record write failed:", e.message));
  console.error("ATTENTION mailed card order:", why);
  return res.status(502).json({
    error: `Something went wrong after your payment. It's being handled, and you won't be charged for a card that isn't mailed. If you need help, write to ${SUPPORT}.`,
    attention: true,
  });
}
