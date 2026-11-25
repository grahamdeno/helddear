// Abuse limits for mailed cards (M8, Nov 25, 2026). Anyone who pays can mail a card to any US address, so:
//  - one payment card can send at most DAILY_CARD_LIMIT cards in 24 hours;
//  - a message that reads as a threat is refused before any payment.
// These sit beside Vercel's rate limits (M3) and Stripe's own fraud checks.
export const DAILY_CARD_LIMIT = 10;

const THREATS = [
  /\b(i('| a)?m going to|i('| wi)ll|gonna)\s+(kill|hurt|find)\s+you\b/i,
  /\bi know where you live\b/i,
  /\byou('re| are)?\s+(going to|gonna)\s+die\b/i,
  /\b(watch your back|you('re| are) dead)\b/i,
];

/** True when the card text reads as a threat. Kept narrow on purpose: everyday words never match. */
export function readsAsThreat(...texts) {
  const t = texts.filter(Boolean).join(" ");
  return THREATS.some((r) => r.test(t));
}

/** True when this payment card has already sent the daily limit. */
export function overDailyLimit(countToday) {
  return countToday >= DAILY_CARD_LIMIT;
}
