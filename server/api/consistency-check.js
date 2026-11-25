import { isTestMode } from "../lib/stripe.js";

// TEST SERVER ONLY (card-test branch, never main): Fable R3. Writes a throwaway record and reads it back at once,
// ten times, and says how many reads were stale. 404 anywhere payments are live.
export default async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");
  if (!isTestMode()) return res.status(404).json({ error: "Not found" });
  const { blobStore } = await import("../lib/blobstore.js");
  const id = `diag/r3-${Date.now()}-${Math.random().toString(36).slice(2)}.json`;
  const rounds = [];
  for (let i = 0; i < 10; i++) {
    const t0 = Date.now();
    await blobStore.putJSON(id, { round: i });
    const back = await blobStore.getJSON(id);
    rounds.push({ round: i, readBack: back?.round ?? null, stale: back?.round !== i, ms: Date.now() - t0 });
  }
  await blobStore.del(id).catch(() => {});
  return res.status(200).json({ stale: rounds.filter((r) => r.stale).length, rounds });
}
