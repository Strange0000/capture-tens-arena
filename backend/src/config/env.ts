import "dotenv/config";
import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().default(8080),
  CLIENT_ORIGIN: z.string().default("*"),
  JWT_SECRET: z.string().min(16).default("development-secret-change-me"),
  JWT_EXPIRES_IN: z.string().default("7d"),
  MONGO_URI: z.string().default("mongodb://localhost:27017/capture_tens"),
  REDIS_URL: z.string().default("redis://localhost:6379"),
  GOOGLE_CLIENT_ID: z.string().optional(),
  RATE_LIMIT_WINDOW_MS: z.coerce.number().default(60000),
  RATE_LIMIT_MAX: z.coerce.number().default(120),
  TURN_TIMEOUT_MS: z.coerce.number().default(18000),
  DISCONNECT_GRACE_MS: z.coerce.number().default(60000),
  BOT_THINK_MS: z.coerce.number().default(900),
  OFFLINE_DEV_MODE: z.string().transform((val) => val.toLowerCase() === "true").default("false")
});

export const env = envSchema.parse(process.env);
