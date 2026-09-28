import { query } from '../db/pool.js';
import { isOnline } from '../realtime/presence.js';

export async function listUsers(req, res) {
  const { rows } = await query(
    `SELECT id, name, email FROM users WHERE id <> $1 ORDER BY name ASC`,
    [req.user.id],
  );

  res.json({
    users: rows.map((u) => ({ ...u, online: isOnline(u.id) })),
  });
}
