import { NextFunction, Request, Response } from "express";

// Configuration comes entirely from the environment (12-factor). App Service
// sets these as app settings - see 5-app-service.tf.
export function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`the environment variable ${name} must be set`);
  }
  return value;
}

export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

export function renderPage(title: string, body: string, refreshSeconds?: number): string {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  ${refreshSeconds ? `<meta http-equiv="refresh" content="${refreshSeconds}">` : ""}
  <title>${escapeHtml(title)}</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 60rem; margin: 2rem auto; padding: 0 1rem; }
    form.generate { display: flex; gap: 0.5rem; align-items: center; margin-bottom: 1rem; }
    form.generate input { width: 5rem; padding: 0.4rem; }
    .flow { color: #555; }
    .notice { background: #eef7ee; border: 1px solid #9c9; padding: 0.5rem 0.75rem; }
    .error { background: #fbeeee; border: 1px solid #c99; padding: 0.5rem 0.75rem; }
    .fired { color: #a00; font-weight: bold; }
    .resolved { color: #070; font-weight: bold; }
    table { border-collapse: collapse; width: 100%; }
    th, td { text-align: left; padding: 0.4rem; border-bottom: 1px solid #ddd; vertical-align: top; }
    td small { color: #666; }
    pre { background: #f6f6f6; padding: 0.5rem; overflow-x: auto; font-size: 0.8rem; }
  </style>
</head>
<body>
${body}
</body>
</html>`;
}

// Express 4 doesn't forward rejected promises from async handlers, so route
// any error to the error handler.
type AsyncHandler = (req: Request, res: Response) => Promise<void>;
export const handle = (fn: AsyncHandler) => (req: Request, res: Response, next: NextFunction) => {
  fn(req, res).catch(next);
};

export function errorHandler(err: Error, _req: Request, res: Response, _next: NextFunction): void {
  console.error(err);
  res.status(500).send("Internal Server Error");
}
