import { blobStore } from "../lib/blobstore.js";
import { cleanup } from "../lib/pages.js";

// Daily (vercel.json cron): deletes every family page 30 days past its day.
export default async function handler(req, res) {
  if (process.env.CRON_SECRET && req.headers.authorization !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: "Unauthorized" });
  }
  try {
    return res.status(200).json({ removed: await cleanup(blobStore) });
  } catch (e) {
    console.error("cleanup failed:", e.message);
    return res.status(502).json({ error: "cleanup failed" });
  }
}
