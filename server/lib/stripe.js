// Stripe REST, no SDK. The secret key lives only in Vercel env STRIPE_SECRET_KEY.
import { LIMITS, within } from "./timeout.js";

const BASE = "https://api.stripe.com/v1";

function form(obj, prefix = "", out = new URLSearchParams()) {
  for (const [k, v] of Object.entries(obj)) {
    if (v === undefined || v === null) continue;
    const key = prefix ? `${prefix}[${k}]` : k;
    if (typeof v === "object" && !Array.isArray(v)) form(v, key, out);
    else if (Array.isArray(v)) v.forEach((item) => out.append(`${key}[]`, String(item)));
    else out.append(key, String(v));
  }
  return out;
}

async function stripe(path, params, idempotencyKey, ms = LIMITS.other) {
  const headers = {
    Authorization: `Bearer ${process.env.STRIPE_SECRET_KEY ?? ""}`,
    "Content-Type": "application/x-www-form-urlencoded",
  };
  if (idempotencyKey) headers["Idempotency-Key"] = idempotencyKey;
  return within(ms, `Stripe ${path.split("/")[1]}`, async (signal) => {
    const r = await fetch(BASE + path, { method: "POST", headers, body: form(params), signal });
    const json = await r.json();
    if (!r.ok) {
      // Stripe's own message stays out of logs and replies; only the status, type and code are kept (N8).
      const err = new Error(`Stripe ${r.status} ${json?.error?.type ?? ""} ${json?.error?.code ?? ""}`.trim());
      err.status = r.status;
      err.code = json?.error?.code;
      err.type = json?.error?.type;
      throw err;
    }
    return json;
  });
}

/** Live only with a live secret or restricted key (Fable N6). Anything else, including no key, is test mode, which
 *  never sends an order to Handwrytten. */
export const isLiveKey = (key) => /^(sk|rk)_live_/.test(key ?? "");
export const isTestMode = (key = process.env.STRIPE_SECRET_KEY) => !isLiveKey(key);

/** Stripe saying this reference's charge was already sent (a reused or in-use idempotency key): treat as already paid
 *  or being paid, never as a declined card (Fable N2). */
export const alreadyPaying = (e) => e?.type === "idempotency_error" || e?.code === "idempotency_key_in_use" || e?.status === 409;

/** Turns the Apple Pay payment token from the iPhone into a Stripe card token. */
export function tokenFromApplePay({ paymentData, transactionIdentifier, network, displayName }) {
  return stripe("/tokens", {
    pk_token: paymentData,
    pk_token_instrument_name: displayName,
    pk_token_payment_network: network,
    pk_token_transaction_id: transactionIdentifier,
  }, undefined, LIMITS.token);
}

/** Charges the fixed card price. The amount is set here, never by the app. */
export function charge({ tokenId, amount, reference, description, cardPrint }) {
  return stripe(
    "/payment_intents",
    {
      amount,
      currency: "usd",
      confirm: true,
      payment_method_types: ["card"],
      payment_method_data: { type: "card", card: { token: tokenId } },
      description,
      metadata: { reference, product: "held-dear-mailed-card", ...(cardPrint ? { card_print: cardPrint } : {}) },
    },
    `charge-${reference}`,
    LIMITS.charge,
  );
}

export function refund(paymentIntentId, reference) {
  return stripe("/refunds", { payment_intent: paymentIntentId }, `refund-${reference}`, LIMITS.refund);
}

export function tagOrder(paymentIntentId, orderId) {
  return stripe(`/payment_intents/${paymentIntentId}`, { metadata: { handwrytten_order_id: orderId } });
}

/**
 * Stripe's search, by the app's reference. Search can lag by a minute, so orders never use it to decide anything
 * (Fable N1); only the daily check uses it, for a started charge whose record never moved on.
 */
export async function searchByReference(reference) {
  const q = encodeURIComponent(`metadata['reference']:'${String(reference).replace(/[^A-Za-z0-9-]/g, "")}'`);
  const r = await fetch(`${BASE}/payment_intents/search?query=${q}&limit=5`, {
    headers: { Authorization: `Bearer ${process.env.STRIPE_SECRET_KEY ?? ""}` },
    signal: AbortSignal.timeout(LIMITS.other),
  });
  const json = await r.json();
  if (!r.ok) throw new Error(`Stripe ${r.status}`);
  const pi = (json.data ?? []).find((p) => p.status === "succeeded");
  if (!pi) return { state: "none" };
  const refunded = (pi.amount_received ?? 0) > 0 && pi.latest_charge && typeof pi.latest_charge === "object"
    ? pi.latest_charge.refunded : false;
  if (refunded || pi.metadata?.refunded === "yes") return { state: "refunded", paymentId: pi.id };
  return { state: "charged", paymentId: pi.id, orderId: pi.metadata?.handwrytten_order_id || null };
}

/** One payment, with its charge, for the daily check (Fable R4): has it been refunded, or marked resolved by a person in
 *  Stripe's dashboard (metadata held_dear_resolved = mailed or refunded)? */
export async function paymentStanding(paymentIntentId) {
  const id = String(paymentIntentId).replace(/[^A-Za-z0-9_]/g, "");
  const r = await fetch(`${BASE}/payment_intents/${id}?expand[]=latest_charge`, {
    headers: { Authorization: `Bearer ${process.env.STRIPE_SECRET_KEY ?? ""}` },
    signal: AbortSignal.timeout(LIMITS.other),
  });
  const pi = await r.json();
  if (!r.ok) throw new Error(`Stripe ${r.status}`);
  const charge = pi.latest_charge && typeof pi.latest_charge === "object" ? pi.latest_charge : null;
  return {
    refunded: Boolean(charge?.refunded) || pi.metadata?.refunded === "yes",
    resolved: ["mailed", "refunded"].includes(pi.metadata?.held_dear_resolved) ? pi.metadata.held_dear_resolved : null,
    orderNumber: pi.metadata?.handwrytten_order_id || null,
  };
}

export function markRefunded(paymentIntentId) {
  return stripe(`/payment_intents/${paymentIntentId}`, { metadata: { refunded: "yes" } });
}
