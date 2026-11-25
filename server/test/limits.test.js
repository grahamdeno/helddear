import { test } from "node:test";
import assert from "node:assert/strict";
import { readsAsThreat, overDailyLimit, DAILY_CARD_LIMIT } from "../lib/limits.js";

test("threats are caught", () => {
  for (const t of ["I know where you live", "I'm going to hurt you", "you are going to die", "Watch your back"]) {
    assert.equal(readsAsThreat(t), true, t);
  }
});

test("everyday cards are never caught", () => {
  for (const t of ["Happy birthday! Love you to pieces", "Thinking of you, we miss Dad so much", "Kill it at the new job!",
                   "You'll find the perfect place", "Dying to see you at Christmas", "Get well soon, we know you'll beat this"]) {
    assert.equal(readsAsThreat(t), false, t);
  }
});

test("the daily limit", () => {
  assert.equal(overDailyLimit(DAILY_CARD_LIMIT - 1), false);
  assert.equal(overDailyLimit(DAILY_CARD_LIMIT), true);
});
