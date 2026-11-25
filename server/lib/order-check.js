// The daily check (Fable N3, N4): paid orders with no order number and no refund after 10 minutes, started charges
// that never resolved, and anything marked for attention. Logs one line per order with a short hash of its reference,
// never names, addresses or the message, and returns the list for the cron's reply.
import { needsAttention } from "./orders.js";

export async function checkOrders(orders, searchByReference, now = Date.now()) {
  const rows = needsAttention(await orders.all(), now);
  const out = [];
  for (const r of rows) {
    let state = r.state;
    if (state === "started" && !r.paymentId && searchByReference && r.reference) {
      // A charge that never confirmed: by now Stripe's search has caught up.
      try {
        const s = await searchByReference(r.reference);
        state = s.state === "none" ? "declined" : `started, Stripe says ${s.state}`;
      } catch { /* leave it for a person */ }
    }
    out.push({ ref: r.ref, state, why: r.why ?? null, updated: r.updated ?? r.created });
    console.error("ATTENTION mailed card order:", r.ref, state, r.why ?? "");
  }
  return out;
}
