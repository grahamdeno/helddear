// Stripe REST, no SDK. The secret key lives only in Vercel env STRIPE_SECRET_KEY.
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

async function stripe(path, params, idempotencyKey) {
  const headers = {
    Authorization: `Bearer ${process.env.STRIPE_SECRET_KEY ?? ""}`,
    "Content-Type": "application/x-www-form-urlencoded",
  };
  if (idempotencyKey) headers["Idempotency-Key"] = idempotencyKey;
  const r = await fetch(BASE + path, { method: "POST", headers, body: form(params) });
  const json = await r.json();
  if (!r.ok) {
    const err = new Error(json?.error?.message || `Stripe ${r.status}`);
    err.status = r.status;
    err.code = json?.error?.code;
    throw err;
  }
  return json;
}

export const isTestMode = () => (process.env.STRIPE_SECRET_KEY ?? "").startsWith("sk_test_");

/** Turns the Apple Pay payment token from the iPhone into a Stripe card token. */
export function tokenFromApplePay({ paymentData, transactionIdentifier, network, displayName }) {
  return stripe("/tokens", {
    pk_token: paymentData,
    pk_token_instrument_name: displayName,
    pk_token_payment_network: network,
    pk_token_transaction_id: transactionIdentifier,
  });
}

/** Charges the fixed card price. The amount is set here, never by the app. */
export function charge({ tokenId, amount, reference, description }) {
  return stripe(
    "/payment_intents",
    {
      amount,
      currency: "usd",
      confirm: true,
      payment_method_types: ["card"],
      payment_method_data: { type: "card", card: { token: tokenId } },
      description,
      metadata: { reference, product: "held-dear-mailed-card" },
    },
    `charge-${reference}`,
  );
}

export function refund(paymentIntentId, reference) {
  return stripe("/refunds", { payment_intent: paymentIntentId }, `refund-${reference}`);
}

export function tagOrder(paymentIntentId, orderId) {
  return stripe(`/payment_intents/${paymentIntentId}`, { metadata: { handwrytten_order_id: orderId } });
}
