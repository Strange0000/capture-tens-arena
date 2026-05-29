import { Redis } from "ioredis";
import { env } from "../config/env.js";

export const redis = new Redis(env.REDIS_URL, { lazyConnect: true });
export const redisPub = new Redis(env.REDIS_URL, { lazyConnect: true });
export const redisSub = new Redis(env.REDIS_URL, { lazyConnect: true });

export async function connectRedis() {
  await Promise.all([redis.connect(), redisPub.connect(), redisSub.connect()]);
}
