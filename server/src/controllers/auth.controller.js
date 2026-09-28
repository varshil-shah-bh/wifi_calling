import bcrypt from 'bcryptjs';
import { query } from '../db/pool.js';
import { HttpError } from '../middleware/error.js';
import { signAccessToken, signRefreshToken, verifyRefreshToken } from '../utils/tokens.js';

const SALT_ROUNDS = 12;
const PUBLIC_COLUMNS = 'id, name, email, created_at AS "createdAt"';
// Real hash of a throwaway string, compared against when the email is unknown so login timing is constant.
const DECOY_HASH = '$2b$12$fGPT9xfMfbD.bCDEwgDOhuYY8yAkvZcDXo2Bp5UYScNgZcGxqtcYG';

function issueTokens(user) {
  return {
    accessToken: signAccessToken(user),
    refreshToken: signRefreshToken(user),
  };
}

export async function register(req, res) {
  const { name, email, password } = req.body;
  const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

  let user;
  try {
    const { rows } = await query(
      `INSERT INTO users (name, email, password_hash)
       VALUES ($1, $2, $3)
       RETURNING ${PUBLIC_COLUMNS}`,
      [name, email, passwordHash],
    );
    user = rows[0];
  } catch (err) {
    if (err.code === '23505') throw new HttpError(409, 'Email is already registered');
    throw err;
  }

  res.status(201).json({ user, ...issueTokens(user) });
}

export async function login(req, res) {
  const { email, password } = req.body;

  const { rows } = await query(
    `SELECT ${PUBLIC_COLUMNS}, password_hash FROM users WHERE LOWER(email) = $1`,
    [email],
  );
  const record = rows[0];

  const ok = await bcrypt.compare(password, record?.password_hash ?? DECOY_HASH);
  if (!record || !ok) throw new HttpError(401, 'Invalid credentials');

  const { password_hash, ...user } = record;
  res.json({ user, ...issueTokens(user) });
}

export async function refresh(req, res) {
  let payload;
  try {
    payload = verifyRefreshToken(req.body.refreshToken);
  } catch {
    throw new HttpError(401, 'Invalid or expired refresh token');
  }

  const { rows } = await query(`SELECT ${PUBLIC_COLUMNS} FROM users WHERE id = $1`, [payload.sub]);
  if (!rows[0]) throw new HttpError(401, 'Invalid or expired refresh token');

  res.json({ user: rows[0], ...issueTokens(rows[0]) });
}

export async function me(req, res) {
  const { rows } = await query(`SELECT ${PUBLIC_COLUMNS} FROM users WHERE id = $1`, [req.user.id]);
  if (!rows[0]) throw new HttpError(404, 'User not found');
  res.json({ user: rows[0] });
}
