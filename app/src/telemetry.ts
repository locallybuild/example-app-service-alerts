import * as appInsights from "applicationinsights";
import { ManagedIdentityEndpointCredential } from "./identity";

// ---------------------------------------------------------------------------
// Application Insights.
//
// This module is imported before Express, because the SDK (built on
// OpenTelemetry) has to patch the http module before anything else loads it -
// that's how it records every incoming request in the AppRequests table
// without any code in the route handlers.
//
// setup() reads APPLICATIONINSIGHTS_CONNECTION_STRING, which says where to send
// telemetry. Local authentication is disabled on the Application Insights
// resource, so the SDK must also send an Entra access token with each batch: it
// asks the credential for one (for https://monitor.azure.com), and the
// credential gets it from the managed identity endpoint.
// ---------------------------------------------------------------------------
appInsights.setup();
appInsights.defaultClient.config.aadTokenCredential = new ManagedIdentityEndpointCredential(process.env.AZURE_CLIENT_ID);
appInsights.start();

export const telemetry = appInsights.defaultClient;
