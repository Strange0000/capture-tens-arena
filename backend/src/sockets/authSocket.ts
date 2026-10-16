import jwt from "jsonwebtoken";
import { Socket } from "socket.io";
import { env } from "../config/env.js";
import { AuthUser } from "../middleware/auth.js";

export interface AuthedSocket extends Socket {
  user?: AuthUser;
}

export function authenticateSocket(socket: AuthedSocket, next: (error?: Error) => void) {
  const token = socket.handshake.auth?.token || socket.handshake.headers.authorization?.toString().replace("Bearer ", "");
  if (!token) {
    if (env.OFFLINE_DEV_MODE) {
      socket.user = { id: `dev-${socket.id.slice(-6)}`, username: "Player", roles: ["user"] };
      return next();
    }
    return next(new Error("Missing auth token"));
  }
  try {
    socket.user = jwt.verify(token, env.JWT_SECRET) as AuthUser;
    next();
  } catch {
    if (env.OFFLINE_DEV_MODE) {
      const decoded = jwt.decode(token) as AuthUser | null;
      if (decoded && decoded.id) {
        socket.user = decoded;
        return next();
      }
      socket.user = { id: `dev-${socket.id.slice(-6)}`, username: "Player", roles: ["user"] };
      return next();
    }
    next(new Error("Invalid auth token"));
  }
}
