// Server switches (Nov 24, 2026), set in Vercel's environment settings. Both start OFF: nothing is open unless a
// setting says so, so a fresh deploy can never open a feature by accident.
//   MAILED_CARDS=open  lets the app list cards and place orders. Anything else: paused, with a plain message.
//   FAMILY_PAGES=on    serves family pages. Anything else: 404. Deleting a page and the daily cleanup always work,
//                      so the 30-day deletion promise holds while pages are off.
export const mailedCardsOpen = (env = process.env) => env.MAILED_CARDS === "open";
export const familyPagesOn = (env = process.env) => env.FAMILY_PAGES === "on";

export const PAUSED = { paused: true, error: "Mailed cards are paused right now. You weren't charged." };

/** The reply when mailed cards are paused, or null when they're open. */
export function pausedReply(env = process.env) {
  return mailedCardsOpen(env) ? null : { status: 503, body: PAUSED };
}

/** The reply when family pages are off (deleting still works), or null when they're on. */
export function pagesOffReply(method, env = process.env) {
  if (familyPagesOn(env) || method === "DELETE") return null;
  return { status: 404, body: { error: "Not found" } };
}
