// Both apps ship as one image; the ROLE app setting decides which this
// container runs as - see 5-app-service.tf. Each is loaded only when it's
// needed, so the receiver doesn't start Application Insights.
const PORT = Number(process.env.PORT ?? 8080);
const ROLE = process.env.ROLE;

async function main(): Promise<void> {
  switch (ROLE) {
    case "app":
      return (await import("./app")).runApp(PORT);
    case "receiver":
      return (await import("./receiver")).runReceiver(PORT);
    default:
      throw new Error(`the environment variable ROLE must be "app" or "receiver", got ${JSON.stringify(ROLE)}`);
  }
}

main().catch((err) => {
  console.error("failed to start:", err);
  process.exit(1);
});
