import { test } from "node:test";
import assert from "node:assert/strict";
import { validateOrder } from "../lib/validate.js";

const cards = [{ id: 101, name: "Balloons", characters: 120 }];
const addr = { firstName: "Mom", lastName: "D", address1: "1 Main St", city: "Wilmington", state: "nc", zip: "28401" };
const good = {
  reference: "abc12345-0000", cardId: 101, message: "Happy birthday, Mom!", wishes: "Love, Graham",
  recipient: addr, sender: { ...addr, firstName: "Graham" },
  applePay: { paymentData: Buffer.from('{"data":"x"}').toString("base64"), transactionIdentifier: "T1", network: "Visa", displayName: "Visa 1234" },
};

test("accepts a good order and uppercases state", () => {
  const r = validateOrder(good, cards);
  assert.equal(r.error, undefined);
  assert.equal(r.value.recipient.state, "NC");
  assert.equal(r.value.applePay.paymentData, '{"data":"x"}');
});

test("rejects unknown cards, long messages and bad ZIPs", () => {
  assert.match(validateOrder({ ...good, cardId: 5 }, cards).error, /isn't available/);
  assert.match(validateOrder({ ...good, message: "x".repeat(200) }, cards).error, /too long/);
  assert.match(validateOrder({ ...good, recipient: { ...addr, zip: "12" } }, cards).error, /ZIP/);
  assert.match(validateOrder({ ...good, sender: { ...addr, state: "ZZ" } }, cards).error, /state/);
  assert.match(validateOrder({ ...good, applePay: {} }, cards).error, /Apple Pay/);
  assert.match(validateOrder({ ...good, reference: "x" }, cards).error, /reference/);
});
