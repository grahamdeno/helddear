import { blobStore } from "../lib/blobstore.js";
import { cleanup } from "../lib/pages.js";
import { makeOrders } from "../lib/orders.js";
import { checkOrders } from "../lib/order-check.js";
import { isTestMode, paymentStanding, searchByReference } from "../lib/stripe.js";

// Daily (vercel.json cron): deletes every family page 30 days past its day, and checks mailed card orders that need a
// person (Fable N3, R4). Vercel's cron sends CRON_SECRET; the order list is only ever given to a request that has it
// (Fable R5), so without the secret set, nobody can read it.
export default async function handler(req, res) {
  res.setHeader?.("Cache-Control", "no-store");
  const secret = process.env.CRON_SECRET;
  const authorized = Boolean(secret) && req.headers.authorization === `Bearer ${secret}`;
  if (secret && !authorized) return res.status(401).json({ error: "Unauthorized" });
  const out = {};
  try {
    out.removed = await cleanup(blobStore);
  } catch (e) {
    console.error("cleanup failed:", e.message);
    out.cleanupFailed = true;
  }
  if (!authorized) {
    out.orders = "CRON_SECRET isn't set, so mailed card orders weren't checked.";
    console.error("ATTENTION mailed card order check skipped: CRON_SECRET isn't set");
  } else {
    try {
      const mode = isTestMode() ? "test" : "live";
      out.orders = await checkOrders(makeOrders(blobStore, mode), { searchByReference, paymentStanding });
      // The same reply, kept where Grok's daily check can open it in Vercel's Storage page (R4). Short hashes and
      // Stripe payment ids only.
      await blobStore.putJSON(`reports/${mode}/order-check.json`, { at: new Date().toISOString(), ...out.orders });
    } catch (e) {
      console.error("order check failed:", e.message);
      out.orderCheckFailed = true;
    }
  }
  return res.status(out.cleanupFailed || out.orderCheckFailed ? 502 : 200).json(out);
}
