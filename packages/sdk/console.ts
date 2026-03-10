import * as repl from "node:repl";
import { createClient, SpreeError } from "./src";

const baseUrl = process.env.SPREE_URL || "http://localhost:3000";
const publishableKey = process.env.SPREE_PUBLISHABLE_KEY || "";

if (!publishableKey) {
  console.log("Usage: SPREE_PUBLISHABLE_KEY=spree_pk_xxx npx tsx console.ts");
  console.log(
    "       SPREE_PUBLISHABLE_KEY=spree_pk_xxx SPREE_URL=https://api.mystore.com npx tsx console.ts",
  );
  console.log("");
}

const client = createClient({ baseUrl, publishableKey });

console.log("Spree SDK Console");
console.log(`Connected to: ${baseUrl}`);
console.log("");
console.log("Available:");
console.log("  client              - Client instance");
console.log("  createClient        - Create new client");
console.log("");
console.log("Examples:");
console.log("  await client.products.list()");
console.log('  await client.products.get("my-product", {}, { locale: "fr" })');
console.log(
  '  await client.categories.get("categories/clothing", {}, { currency: "EUR" })',
);
console.log("");

const r = repl.start({ prompt: "spree> ", useGlobal: true });

// Make await work at top level
r.context.client = client;
r.context.createClient = createClient;
r.context.SpreeError = SpreeError;
