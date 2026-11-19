```
ooooo                                      oooo  oooo              
`888'                                      `888  `888              
 888          .ooooo.   .ooooo.   .oooo.    888   888  oooo    ooo 
 888         d88' `88b d88' `"Y8 `P  )88b   888   888   `88.  .8'
 888         888   888 888        .oP"888   888   888    `88..8'
 888       o 888   888 888   .o8 d8(  888   888   888     `888'
o888ooooood8 `Y8bod8P' `Y8bod8P' `Y888""8o o888o o888o     .8'
                                                       .o..P'
                                                       `Y8P'
```

# Example: Fire an Azure Monitor alert from an App Service app within Locally

This example shows how to fire an Azure Monitor alert end to end, from an app running on App Service through to a webhook that receives it, on [Locally Build](https://locally.build).

The app sends its telemetry to **Application Insights**. A **log search alert rule** counts its failed requests, and once there are too many, an **Action Group** posts the alert to a webhook on a second app that lists the alerts it receives.

```
 app (App Service)
   │  N requests that fail with a 500
   ▼
 Application Insights ──▶ Log Analytics Workspace (AppRequests table)
                                   │
                                   │  every minute: failed AppRequests in the last 5 minutes > 5?
                                   ▼
                          log search alert rule ──▶ Action Group ──▶ webhook (common alert schema)
                                                                        │
                                                          POST /alerts  ▼
                                                                receiver (App Service)
```

There are two apps, written in TypeScript (Node.js and Express). Both run from one image, and the `ROLE` app setting decides which one a container runs as. The source lives in [`app/`](./app), alongside the infrastructure that runs it.

* **app** - a page with a "Generate errors" button. Each click makes a batch of requests to the app's own `/fail` route, which always returns a 500. The Application Insights SDK records every request it serves, so they land in the `AppRequests` table of the Log Analytics Workspace with `Success = false`.
* **receiver** - the endpoint the Action Group's webhook posts to. It keeps the most recent alerts in memory and lists them on its page (alert rule, severity, fired/resolved, when it fired and the value that tripped it), which refreshes every few seconds.

They're separate apps for the same reason they would be on Azure: the thing raising alerts shouldn't be the thing receiving them, or an app that's falling over would also lose the alert about it.

### How the alert works

The alert rule ([`6-alerts.tf`](./modules/app-service-alerts/6-alerts.tf)) runs this query against Application Insights every minute (`evaluation_frequency = "PT1M"`), over the last five minutes of telemetry (`window_duration = "PT5M"`):

```
AppRequests | where Success == false | summarize FailedRequests = sum(ItemCount)
```

When `FailedRequests` is more than 5, the alert fires and the Action Group is notified.

The query adds up `ItemCount` instead of counting rows because the SDK samples requests once there are more than a few a second (5 by default). Each row that's kept stands in for `ItemCount` requests, so a burst of 10 failures can arrive as 5 rows with an `ItemCount` of 2. Counting rows would undercount.

`auto_mitigation_enabled = true` resolves the alert once the count stays back under the threshold. The burst of failures slides out of the window about five minutes after the last click, and the alert is resolved a few evaluations after that. That sends a second notification, with the monitor condition `Resolved`.

The Action Group's webhook uses the [common alert schema](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-common-schema), so the payload has the same `essentials` section whatever kind of alert raised it, and the receiver needs only one parser.

### How the app authenticates to Application Insights

Local authentication is disabled on the Application Insights resource (`local_authentication_enabled = false`). The instrumentation key in the connection string still says where to send telemetry, but it no longer lets anyone send it: each request needs an Entra access token for an identity holding the **Monitoring Metrics Publisher** role.

The app has a **user-assigned managed identity** with that role on the Application Insights resource. [`app/src/identity.ts`](./app/src/identity.ts) gets tokens for it from the App Service managed identity endpoint (`IDENTITY_ENDPOINT` and `IDENTITY_HEADER`), and [`app/src/telemetry.ts`](./app/src/telemetry.ts) hands that credential to the SDK. No key or password is stored in the app's settings.

## Requirements

* [Locally Build](https://locally.build).
* Either [HashiCorp Terraform](https://terraform.io) or [OpenTofu](https://opentofu.org).
* Either [Docker](https://www.docker.com) or [Podman](https://podman.io) (recommended).
* The Locally Plugin for `Microsoft.ContainerRegistry` installed (`locally plugin install --name Microsoft.ContainerRegistry`).
* The Locally Plugin for `Microsoft.Insights` installed (`locally plugin install --name Microsoft.Insights`).
* The Locally Plugin for `Microsoft.OperationalInsights` installed (`locally plugin install --name Microsoft.OperationalInsights`).
* The Locally Plugin for `Microsoft.Web` installed (`locally plugin install --name Microsoft.Web`).

## Running the example

First up, we need to ensure our container runtime (Docker or Podman) is running, then launch Locally:

```bash
locally build
```

With Locally running, in another terminal we can initialise Terraform, which both downloads the providers we need and configures the module for use:

```bash
cd environments/locally
terraform init
```

> [!NOTE]
> It's possible to use OpenTofu here by substituting `terraform` for `tofu`.

With Terraform initialised, we can then provision the example by running:

```bash
locally run terraform apply
```

As part of the apply, the app is built with `docker build` and pushed into the Container Registry, so the `docker` command needs to be available (with Podman, the `podman-docker` shim or a `docker` alias works).

Once you approve the plan and the resources have been deployed, both apps are running at the URLs in the outputs:

```
app_url      = "https://locally-example-alerts-app.furnace.locally:5663"
receiver_url = "https://locally-example-alerts-receiver.furnace.locally:5663"
```

[Open the app](https://locally-example-alerts-app.furnace.locally:5663) and click **Generate errors**, then follow the link to [the receiver](https://locally-example-alerts-receiver.furnace.locally:5663). Within a minute or two the alert arrives with the condition `Fired`. Once the errors have aged out of the five-minute window and the rule has seen a few clean evaluations, a second notification arrives with the condition `Resolved`. Expect that to take 10-15 minutes after the alert fired.

---

We can also see the failed requests the alert rule counts. Query them within [the Locally Dashboard, in the Monitoring section](https://localhost:5678/monitoring/components), or from the CLI with the workspace ID from the outputs:

```
AppRequests | where Success == false | order by TimeGenerated desc
```

```bash
locally run az monitor log-analytics query \
  --workspace "$(terraform output -raw log_analytics_workspace_id)" \
  --analytics-query "AppRequests | where Success == false | summarize sum(ItemCount) by bin(TimeGenerated, 1m)"
```

Both apps also send their console logs to the workspace:

```
AppServiceConsoleLogs | order by TimeGenerated desc
```

## Notes

The receiver's webhook has no authentication of its own: anyone who can reach it can post an alert to it. That keeps the example focused on the alerting wiring. On Azure you could switch on `use_aad_auth` on the webhook receiver, so the Action Group sends an Entra token the receiver can validate.

The threshold, evaluation frequency and window are variables on the module (`alert_threshold`, `alert_evaluation_frequency` and `alert_window_duration`). One minute is the shortest evaluation frequency Azure allows for a log search alert, and it's billed at a higher rate than the default of five minutes - fine for a demo, worth reconsidering for a real one.

The receiver keeps alerts in memory only, so restarting it forgets them.

## Tearing it down

```bash
cd environments/locally
locally run terraform destroy
```
