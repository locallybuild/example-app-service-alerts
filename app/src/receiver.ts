import express, { Request, Response } from "express";
import { errorHandler, escapeHtml, renderPage } from "./web";

// Alerts are kept in memory only: this is a demo, so a restart forgets them.
const MAX_ALERTS = 50;

// ---------------------------------------------------------------------------
// The common alert schema.
//
// With use_common_alert_schema enabled on the Action Group's webhook, every
// alert arrives in the same shape, whatever raised it:
//
//   { "schemaId": "azureMonitorCommonAlertSchema",
//     "data": { "essentials": { ... }, "alertContext": { ... } } }
//
// "essentials" is common to every alert. "alertContext" depends on the kind of
// rule - for a log search alert it holds the query and the value it returned.
// Only the fields shown on the page are typed here.
// ---------------------------------------------------------------------------
interface Essentials {
  alertId?: string;
  alertRule?: string;
  severity?: string;
  signalType?: string;
  monitorCondition?: string;
  monitoringService?: string;
  firedDateTime?: string;
  resolvedDateTime?: string;
  description?: string;
}

interface LogSearchCondition {
  searchQuery?: string;
  metricValue?: number;
  threshold?: string | number;
  operator?: string;
  windowStartTime?: string;
  windowEndTime?: string;
}

interface CommonAlert {
  schemaId?: string;
  data?: {
    essentials?: Essentials;
    alertContext?: { condition?: { allOf?: LogSearchCondition[] } };
  };
}

interface ReceivedAlert {
  receivedAt: string;
  payload: CommonAlert;
}

export async function runReceiver(port: number): Promise<void> {
  // Newest first.
  const alerts: ReceivedAlert[] = [];

  const app = express();

  app.get("/healthz", (_req: Request, res: Response) => {
    res.status(200).send("ok");
  });

  // The Action Group's webhook POSTs each notification here.
  app.post("/alerts", express.json({ limit: "1mb" }), (req: Request, res: Response) => {
    const payload = req.body as CommonAlert;
    const essentials = payload?.data?.essentials;
    if (payload?.schemaId !== "azureMonitorCommonAlertSchema" || !essentials) {
      console.warn(`ignored a request that isn't a common alert schema payload (schemaId ${JSON.stringify(payload?.schemaId)})`);
      res.status(400).send("expected the common alert schema");
      return;
    }
    alerts.unshift({ receivedAt: new Date().toISOString(), payload });
    alerts.length = Math.min(alerts.length, MAX_ALERTS);
    console.log(`received alert "${essentials.alertRule}" (${essentials.severity}): ${essentials.monitorCondition}`);
    res.status(200).send("ok");
  });

  app.get("/", (_req: Request, res: Response) => {
    const rows = alerts
      .map(({ receivedAt, payload }) => {
        const e = payload.data?.essentials ?? {};
        const condition = payload.data?.alertContext?.condition?.allOf?.[0];
        const state = e.monitorCondition ?? "";
        return `
        <tr>
          <td><strong>${escapeHtml(e.alertRule ?? "")}</strong><br><small>${escapeHtml(e.description ?? "")}</small></td>
          <td>${escapeHtml(e.severity ?? "")}</td>
          <td class="${state === "Fired" ? "fired" : "resolved"}">${escapeHtml(state)}</td>
          <td><small>${escapeHtml(e.firedDateTime ?? "")}${e.resolvedDateTime ? `<br>resolved ${escapeHtml(e.resolvedDateTime)}` : ""}</small></td>
          <td><small>${condition ? `${escapeHtml(String(condition.metricValue ?? ""))} ${escapeHtml(condition.operator ?? "")} ${escapeHtml(String(condition.threshold ?? ""))}` : ""}</small></td>
          <td><small>${escapeHtml(receivedAt)}</small></td>
        </tr>
        <tr><td colspan="6"><details><summary><small>Payload</small></summary><pre>${escapeHtml(JSON.stringify(payload, null, 2))}</pre></details></td></tr>`;
      })
      .join("");

    const body = `
      <h1>Receiver</h1>
      <p class="flow">app &rarr; Application Insights &rarr; log search alert rule &rarr; Action Group &rarr; <strong>webhook (POST /alerts)</strong></p>
      <p>The newest ${MAX_ALERTS} alert notifications this receiver has been sent, kept in memory. This page refreshes every 5 seconds.</p>
      <table>
        <thead><tr><th>Alert rule</th><th>Severity</th><th>Condition</th><th>Fired</th><th>Value</th><th>Received</th></tr></thead>
        <tbody>${rows || `<tr><td colspan="6">No alerts yet - generate some errors from the app.</td></tr>`}</tbody>
      </table>`;
    res.send(renderPage("Receiver", body, 5));
  });

  app.use(errorHandler);

  app.listen(port, "0.0.0.0", () => {
    console.log(`receiver listening on 0.0.0.0:${port}, accepting alerts on POST /alerts`);
  });
}
