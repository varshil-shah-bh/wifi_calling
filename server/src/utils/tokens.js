import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';

export function signAccessToken(user) {
  return jwt.sign({ sub: user.id, email: user.email, typ: 'access' }, env.accessSecret, {
    expiresIn: env.accessExpiresIn,
  });
}

export function signRefreshToken(user) {
  return jwt.sign({ sub: user.id, typ: 'refresh' }, env.refreshSecret, {
    expiresIn: env.refreshExpiresIn,
  });
}

export function verifyAccessToken(token) {
  const payload = jwt.verify(token, env.accessSecret);
  if (payload.typ !== 'access') throw new Error('Wrong token type');
  return payload;
}

export function verifyRefreshToken(token) {
  const payload = jwt.verify(token, env.refreshSecret);
  if (payload.typ !== 'refresh') throw new Error('Wrong token type');
  return payload;
}
