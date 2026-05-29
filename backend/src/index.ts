import http from "node:http";
import { Server } from "socket.io";
import { createApp } from "./app.js";
import { env } from "./config/env.js";
import { connectMongo } from "./db/mongo.js";
import { connectRedis } from "./db/redis.js";
import { registerGameSockets } from "./sockets/gameSocket.js";

async function main() {
  if (!env.OFFLINE_DEV_MODE) {
    await Promise.all([connectMongo(), connectRedis()]);
  } else {
    console.log("OFFLINE_DEV_MODE enabled: MongoDB and Redis connections are skipped.");
  }
  const app = createApp();
  const server = http.createServer(app);
  const io = new Server(server, {
    cors: { origin: env.CLIENT_ORIGIN === "*" ? true : env.CLIENT_ORIGIN, credentials: true },
    transports: ["websocket", "polling"]
  });
  registerGameSockets(io);
  server.listen(env.PORT, () => {
    console.log(`Capture Tens backend listening on ${env.PORT}`);
  });
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
