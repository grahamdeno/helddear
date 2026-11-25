// Every call to Stripe or Handwrytten has a time limit (Fable N3), so a failed order's refund finishes well inside the
// function's 30 seconds: Apple Pay token 5 s, charge 7 s, Handwrytten order 8 s, refund 6 s.
export const LIMITS = { token: 5000, charge: 7000, place: 8000, refund: 6000, other: 6000 };

export class TimedOut extends Error {
  constructor(what) { super(`${what} timed out`); this.timedOut = true; }
}

/** Runs fn(signal) and gives up after ms. */
export async function within(ms, what, fn) {
  const signal = AbortSignal.timeout(ms);
  try {
    return await fn(signal);
  } catch (e) {
    if (signal.aborted || e?.name === "TimeoutError" || e?.name === "AbortError") throw new TimedOut(what);
    throw e;
  }
}
