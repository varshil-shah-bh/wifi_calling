import http from 'node:http';
import { Server } from 'socket.io';
import { createApp } from './app.js';
import { env } from './config/env.js';
import { migrate } from './db/migrate.js';
import { pool } from './db/pool.js';
import { registerSignaling } from './sockets/signaling.js';

async function main() {
  await migrate();

  const server = http.createServer(createApp());
  const io = new Server(server, { cors: { origin: env.corsOrigin } });
  registerSignaling(io);

  server.listen(env.port, () => {
    console.log(`Server listening on http://localhost:${env.port}`);
  });

  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.on(signal, async () => {
      await io.close();
      server.close();
      await pool.end();
      process.exit(0);
    });
  }
}

main().catch((err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
