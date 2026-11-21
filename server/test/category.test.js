import { test } from "node:test";
import assert from "node:assert/strict";
import { isPersonal, pickCategory } from "../lib/handwrytten.js";

const cats = [
  { id: 7, name: "Birthday" }, { id: 9, name: "Anniversary" }, { id: 12, name: "Holiday" },
  { id: 15, name: "Congratulations" }, { id: 20, name: "Blank" },
];

test("maps occasions to Handwrytten categories with fallbacks", () => {
  assert.equal(pickCategory(cats, "birthday"), 7);
  assert.equal(pickCategory(cats, "anniversary"), 9);
  assert.equal(pickCategory(cats, "christmas"), 12);
  assert.equal(pickCategory(cats, "graduation"), 15);
  assert.equal(pickCategory(cats, "mothersDay"), 20);
  assert.equal(pickCategory([], "birthday"), null);
});

test("maps card reasons to Handwrytten categories", () => {
  const more = [...cats, { id: 30, name: "Get Well" }, { id: 31, name: "Thank You" },
    { id: 32, name: "Sympathy" }, { id: 33, name: "Thinking of You" }];
  assert.equal(pickCategory(more, "getWell"), 30);
  assert.equal(pickCategory(more, "thankYou"), 31);
  assert.equal(pickCategory(more, "sympathy"), 32);
  assert.equal(pickCategory(more, "thinkingOfYou"), 33);
  assert.equal(pickCategory(more, "justBecause"), 33);
  assert.equal(pickCategory(more, "congratulations"), 15);
  assert.equal(pickCategory(cats, "getWell"), 20);
});

test("leaves out business cards", () => {
  assert.equal(isPersonal("Workiversary Cheers & Confetti"), false);
  assert.equal(isPersonal("Favorite Employee Anniversary Card"), false);
  assert.equal(isPersonal("Celebrating Your Dedication Anniversary Card"), false);
  assert.equal(isPersonal("Gold Anniversary Card"), true);
  assert.equal(isPersonal("Happy Anniversary Balloons"), true);
});
