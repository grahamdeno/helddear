import { blobStore } from "../lib/blobstore.js";
import { cleanup } from "../lib/pages.js";
import { makeOrders } from "../lib/orders.js";
import { checkOrders } from "../lib/order-check.js";
import { isTestMode, searchByReference } from "../lib/stripe.js";

// Daily (vercel.json cron): deletes every family page 30 days past its day, and checks mailed card orders that need a
// person (Fable N3): paid with no order number after 10 minutes, a failed refund, or a charge that never confirmed.
export default async function handler(req, res) {
  if (process.env.CRON_SECRET && req.headers.authorization !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: "Unauthorized" });
  }
  const out = {};
  try {
    out.removed = await cleanup(blobStore);
  } catch (e) {
    console.error("cleanup failed:", e.message);
    out.cleanupFailed = true;
  }
  try {
    out.ordersNeedingAttention = await checkOrders(makeOrders(blobStore, isTestMode() ? "test" : "live"), searchByReference);
  } catch (e) {
    console.error("order check failed:", e.message);
    out.orderCheckFailed = true;
  }
  return res.status(out.cleanupFailed || out.orderCheckFailed ? 502 : 200).json(out);
}
