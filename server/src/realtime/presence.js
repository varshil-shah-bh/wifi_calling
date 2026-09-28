const sockets = new Map(); // userId -> Set<socketId>

export function addSocket(userId, socketId) {
  if (!sockets.has(userId)) sockets.set(userId, new Set());
  const set = sockets.get(userId);
  set.add(socketId);
  return set.size === 1; // became online
}

export function removeSocket(userId, socketId) {
  const set = sockets.get(userId);
  if (!set) return false;
  set.delete(socketId);
  if (set.size > 0) return false;
  sockets.delete(userId);
  return true; // went offline
}

export function isOnline(userId) {
  return sockets.has(userId);
}

export function onlineUserIds() {
  return [...sockets.keys()];
}
