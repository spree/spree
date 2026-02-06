import * as repl from 'node:repl';
import { createSpreeClient, SpreeError } from './src';

const baseUrl = process.env.SPREE_URL || 'http://localhost:3000';
const apiKey = process.env.SPREE_API_KEY || '';

if (!apiKey) {
  console.log('Usage: SPREE_API_KEY=spree_pk_xxx npx tsx console.ts');
  console.log('       SPREE_API_KEY=spree_pk_xxx SPREE_URL=https://api.mystore.com npx tsx console.ts');
  console.log('');
}

const client = createSpreeClient({ baseUrl, apiKey });

console.log('Spree SDK Console');
console.log(`Connected to: ${baseUrl}`);
console.log('');
console.log('Available:');
console.log('  client              - SpreeClient instance');
console.log('  createSpreeClient   - Create new client');
console.log('');
console.log('Examples:');
console.log('  await client.store.get()');
console.log('  await client.products.list()');
console.log('  await client.products.get("my-product", {}, { locale: "fr" })');
console.log('  await client.taxons.get("categories/clothing", {}, { currency: "EUR" })');
console.log('');

const r = repl.start({ prompt: 'spree> ', useGlobal: true });

// Make await work at top level
r.context.client = client;
r.context.createSpreeClient = createSpreeClient;
r.context.SpreeError = SpreeError;
