import { Redis } from "ioredis";
import { env } from "../config/env.js";

export const redisPub = new Redis(env.REDIS_URL, {
  lazyConnect: true,
  maxRetriesPerRequest: 1,
  connectTimeout: 3000,
  retryStrategy: () => null, // don't loop endlessly if redis is down
});
redisPub.on("error", () => {}); // swallow connection errors when offline

export const redisSub = new Redis(env.REDIS_URL, {
  lazyConnect: true,
  maxRetriesPerRequest: 1,
  connectTimeout: 3000,
  retryStrategy: () => null,
});
redisSub.on("error", () => {});

export let isRedisConnected = false;

export async function connectRedis() {
  try {
    await Promise.race([
      Promise.all([redisPub.connect(), redisSub.connect()]),
      new Promise((_, reject) => setTimeout(() => reject(new Error("Redis connection timed out")), 3000)),
    ]);
    isRedisConnected = true;
    console.log("[REDIS] Connected to Redis pub/sub adapter.");
  } catch (err: any) {
    isRedisConnected = false;
    console.warn(`[REDIS] Redis unavailable (${err?.message || err}). Falling back to in-memory adapter.`);
  }
}
