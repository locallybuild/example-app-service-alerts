// Must come first - see telemetry.ts.
import { telemetry } from "./telemetry";

import { randomUUID } from "node:crypto";
import express, { Request, Response } from "express";
import { errorHandler, escapeHtml, handle, renderPage } from "./web";

const MAX_ERRORS = 100;

export async function runApp(port: number): Promise<void> {
  const threshold = Number(process.env.ALERT_THRESHOLD ?? 5);
  const window = process.env.ALERT_WINDOW ?? "PT5M";
  const receiverUrl = process.env.RECEIVER_URL;

  const app = express();
  app.use(express.urlencoded({ extended: false }));

  app.get("/healthz", (_req: Request, res: Response) => {
    res.status(200).send("ok");
  });

  app.get("/", (req: Request, res: Response) => {
    const generated = typeof req.query.generated === "string" ? req.query.generated : undefined;
    const batch = typeof req.query.batch === "string" ? req.query.batch : undefined;
    const body = `
      <h1>App</h1>
      <p class="flow">app &rarr; <strong>Application Insights</strong> (AppRequests in Log Analytics) &rarr; log search alert rule &rarr; Action Group &rarr; webhook &rarr; receiver</p>
      <p>The alert rule fires when there are more than <strong>${escapeHtml(String(threshold))}</strong> failed requests within <strong>${escapeHtml(window)}</strong>. It's evaluated every minute, so give it a minute or two after you click.</p>
      ${generated && batch ? `<p class="notice">Made ${escapeHtml(generated)} failed requests (batch <code>${escapeHtml(batch)}</code>).${receiverUrl ? ` <a href="${escapeHtml(receiverUrl)}">Watch for the alert at the receiver &rarr;</a>` : ""}</p>` : ""}
      <form class="generate" method="post" action="/errors">
        <label for="count">Failed requests</label>
        <input id="count" name="count" type="number" min="1" max="${MAX_ERRORS}" value="${escapeHtml(String(threshold * 2))}">
        <button type="submit">Generate errors</button>
      </form>
      ${receiverUrl ? `<p><a href="${escapeHtml(receiverUrl)}">Open the receiver</a> to see the alerts it has been sent.</p>` : ""}`;
    res.send(renderPage("App", body));
  });

  // Always fails. Application Insights records each call in the AppRequests
  // table with Success = false and ResultCode 500 - what the alert rule counts.
  app.get("/fail", (req: Request, _res: Response) => {
    throw new Error(`Generated error (batch ${String(req.query.batch ?? "")})`);
  });

  // The button calls /fail the requested number of times, over HTTP, so each
  // call is a real failed request rather than a hand-written telemetry item.
  app.post("/errors", handle(async (req, res) => {
    const count = Math.min(Math.max(Math.trunc(Number(req.body.count)) || 1, 1), MAX_ERRORS);
    const batch = randomUUID();
    await Promise.all(
      Array.from({ length: count }, () =>
        fetch(`http://127.0.0.1:${port}/fail?batch=${batch}`, { signal: AbortSignal.timeout(10_000) }).then((r) => r.body?.cancel()),
      ),
    );
    // Send now, rather than waiting for the next scheduled batch, so the
    // failed requests are already in the workspace when the rule next runs.
    await telemetry.flush();
    console.log(`made ${count} failed requests in batch ${batch}`);
    res.redirect(303, `/?generated=${count}&batch=${encodeURIComponent(batch)}`);
  }));

  app.use(errorHandler);

  app.listen(port, "0.0.0.0", () => {
    console.log(`app listening on 0.0.0.0:${port}`);
  });
}
