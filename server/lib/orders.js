// One record per order reference (Fable N1, Nov 25, 2026): written before the charge and read directly, so where an
// order stands never depends on Stripe's search, which can lag by a minute. A record holds only what's needed to
// keep a card from being charged or mailed twice: state, Stripe's payment id, Handwrytten's order number, the payment
// card's Stripe fingerprint, the app's random reference and times. Never names, addresses or the message.
//
// States: started (card checked, charge not yet confirmed) -> charged -> placing -> placed
//         declined (nothing charged) | refunded | attention (a person must look: refund failed, or the outcome
//         is unknown) -> resolved (a person settled it in Stripe; Fable R4). Paths hold a hash of the reference, under the Stripe mode, in Vercel Blob.
import { createHash } from "node:crypto";

export const STATES = ["started", "declined", "charged", "placing", "placed", "refunded", "attention", "resolved"];
const hash = (s) => createHash("sha256").update(String(s)).digest("hex");

export function makeOrders(store, mode) {
  const dir = `orders/${mode}/`;
  const printDir = `prints/${mode}/`;
  const path = (reference) => `${dir}${hash(reference)}.json`;
  return {
    async get(reference) { return store.getJSON(path(reference)); },
    /** Writes the record as base plus fields, without reading it again first (Fable R3): one request carries its own
     *  copy, so a store that's slow to show its last write can't undo a step. */
    async put(reference, fields, base = null) {
      const now = new Date().toISOString();
      // The reference is the app's random id, kept so the daily check can ask Stripe; ref is a short hash for logs.
      const rec = { created: now, ...(base ?? {}), ...fields, reference: String(reference), ref: hash(reference).slice(0, 12), updated: now };
      await store.putJSON(path(reference), rec);
      return rec;
    },
    /** One request's view of one order: read once, then every write builds on the last one in memory. */
    session(reference, base) {
      const orders = this;
      return {
        reference,
        current: base ?? null,
        async write(fields) {
          const next = await orders.put(reference, fields, this.current);
          this.current = next;
          return next;
        },
      };
    },
    /** Rewrites a record found by the daily check (it already has the whole record). */
    async rewrite(rec, fields) { return this.put(rec.reference, fields, rec); },
    /** Marks one paid card against its fingerprint, for the daily limit (N7). */
    async notePrint(cardPrint, reference) {
      await store.putJSON(`${printDir}${hash(cardPrint)}/${hash(reference)}.json`, { at: new Date().toISOString() });
    },
    /** How many cards this payment card started in the last 24 hours. */
    async countToday(cardPrint, now = Date.now()) {
      const rows = await store.listJSON(`${printDir}${hash(cardPrint)}/`);
      return rows.filter((r) => now - Date.parse(r.at) < 86400000).length;
    },
    async all() { return store.listJSON(dir); },
  };
}

/** What the app is told about an order: none, pending, charged (with the order number once placed), refunded or
 *  attention. Nothing about the card or the people. */
export function standingOf(rec) {
  if (!rec || rec.state === "declined") return { state: "none", orderId: null };
  if (rec.state === "started") return { state: "pending", orderId: null };
  if (rec.state === "placed") return { state: "charged", orderId: rec.orderNumber ?? null };
  if (rec.state === "charged" || rec.state === "placing") return { state: "charged", orderId: null };
  if (rec.state === "refunded") return { state: "refunded", orderId: null };
  if (rec.state === "resolved") {
    if (rec.resolution === "refunded") return { state: "refunded", orderId: null };
    if (rec.orderNumber) return { state: "charged", orderId: rec.orderNumber };
    return { state: "attention", orderId: null };
  }
  return { state: "attention", orderId: null };
}

/** Records the daily check should raise (N3): paid with no order number and no refund after 10 minutes, a started
 *  charge that never resolved, and anything marked for attention. */
export function needsAttention(rows, now = Date.now()) {
  const old = (r) => now - Date.parse(r.updated ?? r.created) > 10 * 60 * 1000;
  return rows.filter((r) => r.state === "attention" || (["started", "charged", "placing"].includes(r.state) && old(r)));
}
