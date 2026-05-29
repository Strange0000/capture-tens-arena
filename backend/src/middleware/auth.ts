import { NextFunction, Request, Response } from "express";
import jwt, { SignOptions } from "jsonwebtoken";
import { env } from "../config/env.js";

export interface AuthUser {
  id: string;
  username: string;
  roles: string[];
}

declare module "express-serve-static-core" {
  interface Request {
    user?: AuthUser;
  }
}

export function signJwt(user: AuthUser) {
  return jwt.sign(user, env.JWT_SECRET, { expiresIn: env.JWT_EXPIRES_IN as SignOptions["expiresIn"] });
}

export function requireAuth(req: Request, res: Response, next: NextFunction) {
  const token = req.headers.authorization?.replace("Bearer ", "");
  if (!token) return res.status(401).json({ error: "Missing bearer token" });
  try {
    req.user = jwt.verify(token, env.JWT_SECRET) as AuthUser;
    next();
  } catch {
    res.status(401).json({ error: "Invalid token" });
  }
}
