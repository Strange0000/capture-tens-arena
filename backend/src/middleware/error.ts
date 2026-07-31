import { NextFunction, Request, Response } from "express";

export class AppError extends Error {
  constructor(public statusCode: number, message: string) {
    super(message);
  }
}

export function errorHandler(error: unknown, _req: Request, res: Response, _next: NextFunction) {
  if (error instanceof AppError) {
    return res.status(error.statusCode).json({ error: error.message });
  }
  const message = error instanceof Error ? error.message : "Unexpected error";
  const isValidation = message.toLowerCase().includes('validation') || message.includes('Expected');
  res.status(isValidation ? 400 : 500).json({ error: isValidation ? message : "Internal server error" });
}
