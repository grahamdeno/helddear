// The two web pages family and the person see. Every value is escaped; notes are untrusted text.
export const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

const OPENING = {
  birthday: "Happy birthday", anniversary: "Happy anniversary", christmas: "Merry Christmas",
  valentines: "Happy Valentine's Day", mothersDay: "Happy Mother's Day", fathersDay: "Happy Father's Day",
  newBaby: "Congratulations", graduation: "Congratulations", newHome: "Welcome home", retirement: "Happy retirement",
};
const DAYWORD = {
  birthday: "birthday", anniversary: "anniversary", christmas: "Christmas", valentines: "Valentine's Day",
  mothersDay: "Mother's Day", fathersDay: "Father's Day", newBaby: "new baby", graduation: "graduation",
  newHome: "new home", retirement: "retirement",
};
export const opening = (o) => OPENING[o] ?? OPENING.birthday;
const dayWord = (o) => DAYWORD[o] ?? DAYWORD.birthday;
const longDate = (iso) => new Date(iso + "T12:00:00Z").toLocaleDateString("en-US", { month: "long", day: "numeric", timeZone: "UTC" });
const paragraphs = (t) => esc(t).split("\n").filter(Boolean).map((p) => `<p>${p}</p>`).join("");

export const CSP = "default-src 'none'; img-src https://*.public.blob.vercel-storage.com; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'";

function shell(title, body) {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex, nofollow">
<meta name="referrer" content="no-referrer"><title>${esc(title)}</title>
<style>
:root{color-scheme:light dark;--page:#FAFAF7;--ink:#111;--muted:#6A6A66;--line:#E6E5E0;--accent:#A3472F}
@media (prefers-color-scheme:dark){:root{--page:#111;--ink:#F2F1EC;--muted:#A3A29C;--line:#2C2C2A;--accent:#D07A62}}
*{box-sizing:border-box}body{margin:0;background:var(--page);color:var(--ink);font:17px/1.5 -apple-system,system-ui,sans-serif}
main{max-width:560px;margin:0 auto;padding:40px 22px 64px}
.serif{font-family:"New York","Iowan Old Style",Georgia,serif;font-weight:400;letter-spacing:-.01em}
h1{font-size:40px;line-height:1.1;margin:8px 0 6px}.muted{color:var(--muted)}.eyebrow{color:var(--muted);font-size:13px;font-weight:500}
img.hero{width:100%;aspect-ratio:4/3;object-fit:cover;display:block;margin:0 0 24px}
.note{padding:20px 0;border-top:1px solid var(--line)}.note p{margin:0 0 8px}.from{color:var(--muted);font-size:15px}
.quote{font-style:italic;font-size:21px}
label{display:block;font-size:13px;font-weight:500;color:var(--muted);margin:18px 0 6px}
input[type=text],textarea{width:100%;font:inherit;color:inherit;background:transparent;border:0;border-bottom:1px solid var(--line);padding:8px 0;border-radius:0}
textarea{min-height:120px;resize:vertical}input:focus,textarea:focus{outline:none;border-bottom-color:var(--ink)}
.check{display:flex;gap:10px;align-items:flex-start;margin:20px 0;font-size:15px;color:var(--ink)}
button{width:100%;min-height:54px;font:600 17px -apple-system,system-ui,sans-serif;color:var(--page);background:var(--ink);border:0;border-radius:2px;cursor:pointer}
.ok{border-left:2px solid var(--accent);padding-left:12px;margin:20px 0}.err{color:#B3261E;margin:16px 0}
footer{margin-top:48px;font-size:13px;color:var(--muted)}
</style></head><body><main>${body}</main></body></html>`;
}

export function invitePage({ page, count, id, key, added, error }) {
  const day = dayWord(page.occasion);
  const intro = page.message ? `<div class="note"><p class="quote serif">${paragraphs(page.message)}</p><p class="from">${esc(page.fromName)}</p></div>` : "";
  const body = `
<p class="eyebrow">${esc(longDate(page.date))}</p>
<h1 class="serif">Notes for ${esc(page.firstName)}</h1>
<p class="muted">${esc(page.fromName)} is gathering notes for ${esc(page.firstName)}'s ${esc(day)}. ${esc(page.firstName)} will see them together on the day.</p>
${intro}
${added ? `<p class="ok">Your note is in. Thank you.</p>` : ""}
${error ? `<p class="err">${esc(error)}</p>` : ""}
<form method="post" action="/api/notes">
<input type="hidden" name="id" value="${esc(id)}"><input type="hidden" name="k" value="${esc(key)}">
<label for="name">Your name</label><input type="text" id="name" name="name" maxlength="40" autocomplete="given-name" required>
<label for="text">Your note</label><textarea id="text" name="text" maxlength="500" required></textarea>
<label class="check"><input type="checkbox" name="consent" required> Show my note and name to ${esc(page.firstName)} and ${esc(page.fromName)}.</label>
<button type="submit">Add my note</button>
</form>
<p class="muted" style="margin-top:16px">${count === 1 ? "1 note so far." : `${count} notes so far.`}</p>
<footer>No account needed. This page and every note on it are deleted 30 days after the day. Made with Held Dear.</footer>`;
  return shell(`Notes for ${page.firstName}`, body);
}

export function giftPage({ page, notes }) {
  const photo = page.photoURL ? `<img class="hero" src="${esc(page.photoURL)}" alt="">` : "";
  const list = notes.map((n) => `<div class="note">${paragraphs(n.text)}<p class="from">${esc(n.name)}</p></div>`).join("");
  const own = page.message ? `<div class="note"><p class="quote serif">${paragraphs(page.message)}</p><p class="from">${esc(page.fromName)}</p></div>` : "";
  const body = `${photo}
<p class="eyebrow">${esc(longDate(page.date))}</p>
<h1 class="serif">${esc(opening(page.occasion))}, ${esc(page.firstName)}</h1>
<p class="muted">${notes.length === 0 ? "" : notes.length === 1 ? "A note from someone who loves you." : `${notes.length} notes from people who love you.`}</p>
${own}${list}
<footer>This page is deleted 30 days after the day. Made with Held Dear.</footer>`;
  return shell(`${opening(page.occasion)}, ${page.firstName}`, body);
}

export function gonePage(status) {
  const msg = status === 410 ? "This page has ended. Pages are deleted 30 days after the day." : "This link isn't valid.";
  return shell("Held Dear", `<h1 class="serif">Held Dear</h1><p class="muted">${esc(msg)}</p>`);
}
