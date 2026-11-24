// GET /api/health: alive or not. Nothing about keys or payment mode (M11, Nov 24, 2026).
export default function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");
  res.status(200).json({ ok: true });
}
