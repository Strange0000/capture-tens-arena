import cors from "cors";
import express from "express";
import helmet from "helmet";
import { env } from "./config/env.js";
import { errorHandler } from "./middleware/error.js";
import { apiRateLimit } from "./middleware/rateLimit.js";
import { adminRouter } from "./routes/admin.js";
import { authRouter } from "./routes/auth.js";
import { playtestRouter } from "./routes/playtest.js";
import { usersRouter } from "./routes/users.js";

export function createApp() {
  const app = express();
  app.set("trust proxy", true);
  app.use(
    helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'", "'unsafe-inline'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          connectSrc: ["'self'", "ws:", "wss:"],
        },
      },
    })
  );
  app.use(cors({ origin: env.CLIENT_ORIGIN === "*" ? true : env.CLIENT_ORIGIN, credentials: true }));
  app.use(express.json({ limit: "128kb" }));
  app.use(apiRateLimit);

  app.get("/health", (_req, res) => res.json({ ok: true }));
  app.use("/", playtestRouter);
  app.use("/auth", authRouter);
  app.use("/users", usersRouter);
  app.use("/admin", adminRouter);
  app.use(errorHandler);
  return app;
}
