import { verifyAccessToken } from '../utils/tokens.js';
import { addSocket, isOnline, onlineUserIds, removeSocket } from '../realtime/presence.js';

// Events the server blindly forwards to the target peer; WebRTC media never touches the server.
const RELAYED_EVENTS = [
  'call:invite',
  'call:accept',
  'call:reject',
  'call:end',
  'webrtc:offer',
  'webrtc:answer',
  'webrtc:ice-candidate',
];

export function registerSignaling(io) {
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token) return next(new Error('unauthorized'));
    try {
      const payload = verifyAccessToken(token);
      socket.data.userId = payload.sub;
      next();
    } catch {
      next(new Error('unauthorized'));
    }
  });

  io.on('connection', (socket) => {
    const userId = socket.data.userId;
    socket.join(userId);

    if (addSocket(userId, socket.id)) {
      socket.broadcast.emit('presence:update', { userId, online: true });
    }
    socket.emit('presence:snapshot', { onlineUserIds: onlineUserIds() });

    for (const event of RELAYED_EVENTS) {
      socket.on(event, (payload = {}) => {
        const { to, ...rest } = payload;
        if (!to) return;
        if (!isOnline(to)) {
          socket.emit('peer:unavailable', { to });
          return;
        }
        socket.to(to).emit(event, { ...rest, from: userId });
      });
    }

    socket.on('disconnect', () => {
      if (removeSocket(userId, socket.id)) {
        socket.broadcast.emit('presence:update', { userId, online: false });
      }
    });
  });
}
