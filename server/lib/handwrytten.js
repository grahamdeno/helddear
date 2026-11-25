// Handwrytten API (https://api.handwrytten.com/v2). The key lives only in Vercel env HANDWRYTTEN_API_KEY.
import { LIMITS, within } from "./timeout.js";
import { isLiveKey } from "./stripe.js";

const BASE = "https://api.handwrytten.com/v2";

export async function hw(path, { method = "GET", body, ms = LIMITS.other } = {}) {
  return within(ms, "Handwrytten", async (signal) => {
    const r = await fetch(BASE + path, {
      method,
      headers: {
        Authorization: process.env.HANDWRYTTEN_API_KEY ?? "",
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: body ? JSON.stringify(body) : undefined,
      signal,
    });
    const json = await r.json().catch(() => ({}));
    if (!r.ok || json.status === "error" || (json.httpCode && json.httpCode >= 400)) {
      // Only the status codes, never Handwrytten's message: it can repeat an address or the card text (Fable N8).
      const err = new Error(`Handwrytten ${r.status}${json.httpCode ? ` ${json.httpCode}` : ""}`);
      err.status = r.status;
      throw err;
    }
    return json;
  });
}

export const pickList = (json, ...keys) => {
  for (const k of keys) if (Array.isArray(json?.[k])) return json[k];
  return [];
};

// Which Handwrytten category to show for each Held Dear occasion. Unknown occasions get birthday cards' fallback chain.
export const OCCASION_CATEGORY = {
  birthday: [/birthday/i],
  anniversary: [/anniversar/i, /love/i],
  christmas: [/christmas/i, /holiday/i],
  valentines: [/valentine/i, /love/i],
  mothersDay: [/mother/i, /everyday/i],
  fathersDay: [/father/i, /everyday/i],
  newBaby: [/baby/i, /congrat/i],
  graduation: [/graduat/i, /congrat/i],
  newHome: [/housewarm/i, /new home/i, /congrat/i],
  retirement: [/retire/i, /congrat/i],
  wedding: [/wedding/i, /congrat/i, /love/i],
  event: [/congrat/i],
  // A card for a reason, not a day (story 2.8). Keys match the app's CardReason raw values.
  justBecause: [/thinking/i, /blank/i, /friend/i, /everyday/i, /just for fun/i],
  getWell: [/get well/i, /feel better/i],
  thankYou: [/thank(?!sgiving)/i],
  thinkingOfYou: [/thinking/i, /friend/i, /everyday/i],
  congratulations: [/congrat/i],
  sympathy: [/sympathy/i, /condolence/i],
};

// Categories that aren't personal cards: photo templates, business, invitations (checked Nov 21, 2026 against
// Handwrytten's list: "Birthday (Photo Templates)" has 4 cards, "Birthday (Personal)" has 50).
const NOT_PERSONAL_CATEGORY = /photo template|business|customer|employee|donor|volunteer|real estate|homiversary|invitation|all categories|favorites/i;

// Reasons where a wrong card would hurt (M5, Nov 24, 2026): only their own categories, never a general fallback.
// No match means no cards, and the app says none are available.
export const STRICT_OCCASIONS = new Set(["sympathy"]);

export function pickCategory(cats, occasion) {
  const usable = cats.filter((c) => c.id > 0 && !NOT_PERSONAL_CATEGORY.test(c.name ?? ""));
  const own = OCCASION_CATEGORY[occasion] ?? [];
  const patterns = STRICT_OCCASIONS.has(occasion) ? own : [...own, /blank/i, /everyday/i, /thinking/i, /general/i];
  for (const re of patterns) {
    const matches = usable.filter((c) => re.test(c.name ?? ""));
    const best = matches.find((c) => /personal/i.test(c.name ?? "")) ?? matches[0];
    if (best?.id) return best.id;
  }
  return null;
}

/** The occasion's own category, with its name, so the app's menu opens on it. */
export async function ownSection(occasion = "birthday") {
  try {
    const cats = pickList(await hw("/categories/list"), "categories", "data", "items");
    const id = pickCategory(cats, occasion);
    const c = cats.find((x) => x.id === id);
    return c ? sectionName(c.name) : null;
  } catch { return null; }
}

export async function categoryId(occasion = "birthday") {
  try {
    const cats = pickList(await hw("/categories/list"), "categories", "data", "items");
    const id = pickCategory(cats, occasion);
    if (id) return id;
  } catch {}
  // Only a birthday falls back to Handwrytten's documented Birthday category. Any other occasion gets no cards rather
  // than birthday cards (M5): a sympathy card must never become a birthday card.
  return occasion === "birthday" ? 7 : null;
}

// Business cards (work anniversaries, employee thank-yous) share categories with personal ones; leave them out.
const BUSINESS = /work|employee|staff|team|client|customer|service|dedication|contribution|excellence|achievement|success|commitment|journey with us|hard work|business|company/i;
export const isPersonal = (name) => !BUSINESS.test(String(name ?? ""));

// Categories that suit any card ("More cards" in the app, Nov 21, 2026): blank, general, thinking of you, friendship.
export const ANY_OCCASION = [/blank/i, /^everyday/i, /just for fun/i, /general/i, /thinking/i, /friend/i, /any occasion/i];

/** Ids of the "any occasion" categories, other than the occasion's own. */
export function anyOccasionCategories(cats, excludeId) {
  const ids = [];
  for (const re of ANY_OCCASION) {
    for (const c of cats) {
      if (c.id > 0 && c.id !== excludeId && !NOT_PERSONAL_CATEGORY.test(c.name ?? "") && re.test(c.name ?? "") && !ids.includes(c.id)) ids.push(c.id);
    }
  }
  return ids.slice(0, 4);
}

/** More cards beyond the occasion's own: any-occasion designs, without the ones already shown. Up to 40. */
export async function listMoreCards(occasion = "birthday", shownIds = []) {
  if (STRICT_OCCASIONS.has(occasion)) return []; // No cheerful "more cards" beside sympathy cards (M5).
  let cats = [];
  try { cats = pickList(await hw("/categories/list"), "categories", "data", "items"); } catch { return []; }
  const own = await categoryId(occasion);
  const seen = new Set(shownIds);
  const more = [];
  for (const id of anyOccasionCategories(cats, own)) {
    try {
      for (const c of await cardsIn(id)) {
        if (!seen.has(c.id)) { seen.add(c.id); more.push(c); }
      }
    } catch {}
  }
  return more.slice(0, 40);
}

/** One Handwrytten card as the app shows it. The description helps search (Nov 22, 2026). */
// Card pictures go through Held Dear's server (M6): a path on this server, never Handwrytten's address. Vercel's
// image service on this same server fetches the original once, shrinks it to 480 pixels wide and caches it for 30
// days (Nov 25, 2026: Handwrytten's full-size fronts were too large to pass through a function, so most never loaded).
// Only Handwrytten's card image folder is allowed (vercel.json images.remotePatterns).
export const viaServer = (url) => (url ? `/_vercel/image?url=${encodeURIComponent(url)}&w=480&q=75` : null);

export function toAppCard(c) {
  return {
    id: Number(c.id),
    name: String(c.name ?? "Card"),
    description: c.description ? String(c.description).slice(0, 200) : null,
    cover: viaServer(c.cover),
    inside: viaServer(c.inside_image ?? null),
    characters: Number(c.characters) || 300,
    orientation: c.orientation ?? null,
  };
}

async function cardsIn(id) {
  const json = await hw(`/cards/list?category_id=${id}&with_images=1`);
  return pickList(json, "cards", "data", "items")
    .filter((c) => c.cover && c.id && isPersonal(c.name))
    .map(toAppCard);
}

/** "Birthday (Personal)" reads "Birthday"; other names stay as Handwrytten writes them. */
export function sectionName(name) {
  return String(name ?? "").replace(/\s*\((personal|cards?)\)\s*$/i, "").trim();
}

/** The personal categories, in Handwrytten's order, for the app's category menu (Nov 22, 2026). */
export function personalCategories(cats) {
  return cats.filter((c) => c.id > 0 && c.name && !NOT_PERSONAL_CATEGORY.test(c.name));
}

/**
 * Every personal category with its cards, for the category menu and search in the app (Nov 22, 2026):
 * [{ name: "Birthday", cards: [...] }]. Empty categories are left out; up to 30 categories, 60 cards each.
 */
export async function listSections() {
  let cats = [];
  try { cats = pickList(await hw("/categories/list"), "categories", "data", "items"); } catch { return []; }
  const usable = personalCategories(cats).slice(0, 30);
  const lists = await Promise.all(usable.map((c) => cardsIn(c.id).catch(() => [])));
  const merged = new Map();
  usable.forEach((c, i) => {
    const name = sectionName(c.name);
    const cards = lists[i].slice(0, 60);
    if (!cards.length || !name) return;
    const have = merged.get(name) ?? [];
    for (const card of cards) if (!have.some((h) => h.id === card.id)) have.push(card);
    merged.set(name, have);
  });
  return [...merged].map(([name, cards]) => ({ name, cards }));
}

/** Cards for an occasion with a cover image, as the app shows them. */
export async function listCards(occasion = "birthday") {
  const id = await categoryId(occasion);
  if (!id) return [];
  const json = await hw(`/cards/list?category_id=${id}&with_images=1`);
  return pickList(json, "cards", "data", "items")
    .filter((c) => c.cover && c.id && isPersonal(c.name))
    .map(toAppCard)
    .slice(0, 60);
}

// Every card the app's picker can show for an occasion: its own, "more", and every category (Fable N5). Kept for
// ten minutes in a warm function, so an order doesn't fetch every category again.
const pickerCache = new Map();
export async function pickerCards(occasion = "birthday", now = Date.now()) {
  const hit = pickerCache.get(occasion);
  if (hit && now - hit.at < 600000) return hit.cards;
  const own = await listCards(occasion);
  const [more, sections] = await Promise.all([
    listMoreCards(occasion, own.map((c) => c.id)).catch(() => []),
    listSections().catch(() => []), // the category menu shows every category, sympathy included
  ]);
  const byId = new Map();
  for (const c of [...own, ...more, ...sections.flatMap((x) => x.cards)]) if (!byId.has(c.id)) byId.set(c.id, c);
  const cards = [...byId.values()];
  pickerCache.set(occasion, { at: now, cards });
  return cards;
}

export async function fontLabel() {
  if (process.env.HANDWRYTTEN_FONT) return process.env.HANDWRYTTEN_FONT;
  try {
    const fonts = pickList(await hw("/fonts/list"), "fonts", "data", "items");
    const f = fonts.find((x) => x.label || x.name);
    if (f) return f.label ?? f.name;
  } catch {}
  return "Chill Charity"; // Handwrytten's documented example label
}

/** Places one card, pen-written and mailed with the sender's return address. Returns Handwrytten's order id. */
export async function placeOrder(o, key = process.env.STRIPE_SECRET_KEY) {
  // A second lock beside order.js's test-mode check (Fable N6): the test server holds Handwrytten's key so it can list
  // cards, but no order is ever sent unless payments are live.
  if (!isLiveKey(key)) throw new Error("Handwrytten orders are only placed with live payments");
  const json = await hw("/orders/singleStepOrder", {
    method: "POST",
    ms: LIMITS.place,
    body: {
      font_label: await fontLabel(),
      card_id: o.cardId,
      message: o.message,
      wishes: o.wishes,
      recipient_first_name: o.recipient.firstName,
      recipient_last_name: o.recipient.lastName,
      recipient_address1: o.recipient.address1,
      recipient_address2: o.recipient.address2 || undefined,
      recipient_city: o.recipient.city,
      recipient_state: o.recipient.state,
      recipient_zip: o.recipient.zip,
      sender_first_name: o.sender.firstName,
      sender_last_name: o.sender.lastName,
      sender_address1: o.sender.address1,
      sender_address2: o.sender.address2 || undefined,
      sender_city: o.sender.city,
      sender_state: o.sender.state,
      sender_zip: o.sender.zip,
      validate_address: true,
      client_metadata: o.reference,
    },
  });
  return json.order_id ?? json.id ?? null;
}
