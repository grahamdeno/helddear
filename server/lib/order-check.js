// The daily check (Fable N3, N4, R4): paid orders with no order number and no refund after 10 minutes, started charges
// that never resolved, and anything marked for attention. Each is settled from Stripe where it can be:
//  - a started charge Stripe never took becomes declined;
//  - a payment refunded in Stripe, or marked by a person in Stripe's dashboard with the metadata
//    held_dear_resolved = mailed or refunded, becomes resolved;
//  - a payment Stripe shows with a Handwrytten order number becomes resolved, mailed.
// What's left is listed in the cron's reply and logged, one line each, by a short hash and Stripe's payment id:
// never names, addresses or the message.
import { needsAttention } from "./orders.js";

export async function checkOrders(orders, stripe, now = Date.now()) {
  const rows = needsAttention(await orders.all(), now);
  const open = [];
  const settled = [];
  for (const r of rows) {
    try {
      if (r.state === "started" && !r.paymentId) {
        const s = await stripe.searchByReference(r.reference);
        if (s.state === "none") { await orders.rewrite(r, { state: "declined" }); settled.push({ ref: r.ref, to: "declined" }); continue; }
        await orders.rewrite(r, { state: "attention", why: `charge found by search: ${s.state}`, paymentId: s.paymentId ?? null });
        r.paymentId = s.paymentId ?? null;
        r.why = `charge found by search: ${s.state}`;
      } else if (r.paymentId) {
        const p = await stripe.paymentStanding(r.paymentId);
        const resolution = p.resolved ?? (p.refunded ? "refunded" : p.orderNumber ? "mailed" : null);
        if (resolution) {
          await orders.rewrite(r, { state: "resolved", resolution, orderNumber: p.orderNumber ?? r.orderNumber ?? null });
          settled.push({ ref: r.ref, to: `resolved, ${resolution}` });
          continue;
        }
      }
    } catch (e) {
      r.why = `${r.why ?? ""} (check failed: ${e.message})`.trim();
    }
    open.push({ ref: r.ref, state: r.state, paymentId: r.paymentId ?? null, why: r.why ?? null, updated: r.updated ?? r.created });
    console.error("ATTENTION mailed card order:", r.ref, r.state, r.paymentId ?? "", r.why ?? "");
  }
  return { open, settled };
}
