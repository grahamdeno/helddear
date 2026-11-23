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

test("a get-well card never falls back to sympathy designs", () => {
  const only = [{ id: 40, name: "Sympathy" }, { id: 41, name: "Blank" }];
  assert.equal(pickCategory(only, "getWell"), 41);
});

test("leaves out business cards", () => {
  assert.equal(isPersonal("Workiversary Cheers & Confetti"), false);
  assert.equal(isPersonal("Favorite Employee Anniversary Card"), false);
  assert.equal(isPersonal("Celebrating Your Dedication Anniversary Card"), false);
  assert.equal(isPersonal("Gold Anniversary Card"), true);
  assert.equal(isPersonal("Happy Anniversary Balloons"), true);
});

import { anyOccasionCategories } from "../lib/handwrytten.js";

test("more cards come from any-occasion categories, never the occasion's own", () => {
  const cats = [
    { id: 7, name: "Birthday" },
    { id: 12, name: "Blank" },
    { id: 15, name: "Thinking of You" },
    { id: 40, name: "Sympathy" },
    { id: 22, name: "Friendship" },
  ];
  assert.deepEqual(anyOccasionCategories(cats, 7), [12, 15, 22]);
  assert.deepEqual(anyOccasionCategories(cats, 12), [15, 22]);
});

test("real Handwrytten names: personal categories win, photo templates and business are skipped", () => {
  const real = [
    { id: -1, name: "All Categories" }, { id: 1948, name: "Birthday (Photo Templates)" },
    { id: 1892, name: "Birthday (Business)" }, { id: 1891, name: "Birthday (Personal)" },
    { id: 1888, name: "Anniversary (Business)" }, { id: 1890, name: "Anniversary (Personal)" },
    { id: 11, name: "Condolences" }, { id: 15, name: "Everyday" }, { id: 12, name: "Holidays" },
    { id: 5, name: "Just For Fun" }, { id: 1949, name: "Everyday (Photo Templates)" }, { id: 6, name: "Thank You" },
    { id: 1898, name: "Donor Thank You and Volunteer Appreciation" }, { id: 1440, name: "Get Well" },
  ];
  assert.equal(pickCategory(real, "birthday"), 1891);
  assert.equal(pickCategory(real, "anniversary"), 1890);
  assert.equal(pickCategory(real, "christmas"), 12);
  assert.equal(pickCategory(real, "sympathy"), 11);
  assert.equal(pickCategory(real, "thankYou"), 6);
  assert.equal(pickCategory(real, "mothersDay"), 15);
  assert.equal(pickCategory(real, "justBecause"), 15);
  assert.deepEqual(anyOccasionCategories(real, 1891), [15, 5]);
});

// Category menu and search (Nov 22, 2026).
import { sectionName, personalCategories, toAppCard } from "../lib/handwrytten.js";

test("section names drop (Personal) and keep the rest", () => {
  assert.equal(sectionName("Birthday (Personal)"), "Birthday");
  assert.equal(sectionName("Mother's Day"), "Mother's Day");
  assert.equal(sectionName("Thank You (Cards)"), "Thank You");
});

test("only personal categories go to the menu", () => {
  const cats = [{ id: 1, name: "Birthday (Personal)" }, { id: 2, name: "Birthday (Photo Templates)" },
    { id: 3, name: "Employee Appreciation" }, { id: 0, name: "All Categories" }, { id: 4, name: "Sympathy" }];
  assert.deepEqual(personalCategories(cats).map((c) => c.id), [1, 4]);
});

test("a card carries its description for search, capped", () => {
  const c = toAppCard({ id: "9", name: "Bloom", description: "x".repeat(300), cover: "u" });
  assert.equal(c.id, 9);
  assert.equal(c.description.length, 200);
  assert.equal(toAppCard({ id: 1, name: "A", cover: "u" }).description, null);
});
