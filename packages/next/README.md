# @spree/next

Next.js integration for Spree Commerce — server actions, caching, and cookie-based auth.

## Installation

```bash
npm install @spree/next @spree/sdk
# or
yarn add @spree/next @spree/sdk
# or
pnpm add @spree/next @spree/sdk
```

## Quick Start

### 1. Set environment variables

```env
SPREE_API_URL=https://api.mystore.com
SPREE_API_KEY=your-publishable-api-key
```

The client auto-initializes from these env vars. Alternatively, initialize explicitly:

```typescript
// lib/storefront.ts
import { initSpreeNext } from '@spree/next';

initSpreeNext({
  baseUrl: process.env.SPREE_API_URL!,
  apiKey: process.env.SPREE_API_KEY!,
});
```

### 2. Fetch data in Server Components

```typescript
import { listProducts, getProduct, listTaxons } from '@spree/next';

export default async function ProductsPage() {
  const products = await listProducts({ per_page: 12 });
  const categories = await listTaxons({ 'q[depth_eq]': 1 });

  return (
    <div>
      {products.data.map((product) => (
        <div key={product.id}>{product.name}</div>
      ))}
    </div>
  );
}
```

### 3. Use server actions for mutations

```typescript
import { addItem, removeItem, getCart } from '@spree/next';

export default async function CartPage() {
  const cart = await getCart();

  async function handleAddItem(formData: FormData) {
    'use server';
    await addItem(formData.get('variantId') as string, 1);
  }

  return <form action={handleAddItem}>...</form>;
}
```

## Configuration

```typescript
import { initSpreeNext } from '@spree/next';

initSpreeNext({
  baseUrl: 'https://api.mystore.com',
  apiKey: 'your-publishable-api-key',
  cartCookieName: '_spree_cart_token',     // default
  accessTokenCookieName: '_spree_jwt',     // default
  defaultLocale: 'en',
  defaultCurrency: 'USD',
});
```

## Data Functions

Plain async functions for reading data in Server Components. Wrap with `"use cache"` in your app for caching.

### Products

```typescript
import { listProducts, getProduct, getProductFilters } from '@spree/next';

const products = await listProducts({ per_page: 25, includes: 'variants,images' });
const product = await getProduct('spree-tote');
const filters = await getProductFilters({ taxon_id: 'txn_123' });
```

### Categories

```typescript
import { listTaxons, getTaxon, listTaxonProducts } from '@spree/next';
import { listTaxonomies, getTaxonomy } from '@spree/next';

const taxons = await listTaxons({ 'q[depth_eq]': 1 });
const taxon = await getTaxon('categories/clothing');
const products = await listTaxonProducts('categories/clothing', { per_page: 12 });

const taxonomies = await listTaxonomies({ includes: 'taxons' });
const taxonomy = await getTaxonomy('tax_123');
```

### Store & Geography

```typescript
import { getStore, listCountries, getCountry } from '@spree/next';

const store = await getStore();
const countries = await listCountries();
const usa = await getCountry('US');
```

## Server Actions

Server actions handle mutations and auth-dependent reads. They automatically manage cookies for cart tokens and JWT authentication.

### Cart

```typescript
import { getCart, getOrCreateCart, addItem, updateItem, removeItem, clearCart } from '@spree/next';

const cart = await getCart();
const cart = await getOrCreateCart();
await addItem(variantId, quantity, { gift_message: 'Happy Birthday!' });
await updateItem(lineItemId, { quantity: 3 });
await updateItem(lineItemId, { metadata: { engraving: 'J.D.' } });
await removeItem(lineItemId);
await clearCart();
```

### Checkout

```typescript
import {
  getCheckout,
  updateAddresses,
  advance,
  next,
  getShipments,
  selectShippingRate,
  applyCoupon,
  removeCoupon,
  complete,
} from '@spree/next';

const checkout = await getCheckout();
await updateAddresses({ ship_address: { ... }, bill_address: { ... } });
await advance();
await next();
const shipments = await getShipments();
await selectShippingRate(shipmentId, rateId);
await applyCoupon('SAVE20');
await removeCoupon(promoId);
await complete();
```

### Authentication

```typescript
import { login, register, logout, getCustomer, updateCustomer } from '@spree/next';

await login(email, password);
await register({ email, password, password_confirmation, first_name, last_name });
await logout();
const customer = await getCustomer();
await updateCustomer({ first_name: 'John' });
```

### Addresses

```typescript
import { listAddresses, getAddress, createAddress, updateAddress, deleteAddress } from '@spree/next';

const addresses = await listAddresses();
const address = await getAddress(addressId);
await createAddress({ firstname: 'John', address1: '123 Main St', ... });
await updateAddress(addressId, { city: 'Brooklyn' });
await deleteAddress(addressId);
```

### Orders

```typescript
import { listOrders, getOrder } from '@spree/next';

const orders = await listOrders();
const order = await getOrder(orderId);
```

### Payment Sessions

```typescript
import {
  createPaymentSession,
  getPaymentSession,
  updatePaymentSession,
  completePaymentSession,
} from '@spree/next';

// Create a payment session (initializes provider-specific session)
const session = await createPaymentSession(orderId, { payment_method_id: 'pm_123' });

// Access provider data (e.g., Stripe client secret)
const clientSecret = session.external_data.client_secret;

// Get a payment session
const session = await getPaymentSession(orderId, sessionId);

// Update a payment session
await updatePaymentSession(orderId, sessionId, { amount: '50.00' });

// Complete a payment session (confirms payment with provider)
await completePaymentSession(orderId, sessionId, { session_result: 'success' });
```

### Credit Cards & Gift Cards

```typescript
import { listCreditCards, deleteCreditCard } from '@spree/next';
import { listGiftCards, getGiftCard } from '@spree/next';

const cards = await listCreditCards();
await deleteCreditCard(cardId);

const giftCards = await listGiftCards();
const giftCard = await getGiftCard(giftCardId);
```

## Localization

Pass locale and currency options to data functions:

```typescript
const products = await listProducts({ per_page: 10 }, { locale: 'fr', currency: 'EUR' });
const taxon = await getTaxon('categories/clothing', {}, { locale: 'de', currency: 'EUR' });
```

## TypeScript

All types are re-exported from `@spree/sdk` for convenience:

```typescript
import type {
  StoreProduct,
  StoreOrder,
  StoreLineItem,
  StorePaymentSession,
  StoreTaxon,
  PaginatedResponse,
  SpreeError,
} from '@spree/next';
```

## Development

```bash
cd packages/next
pnpm install
pnpm dev         # Build in watch mode
pnpm typecheck   # Type-check
pnpm test        # Run tests
pnpm build       # Production build
```

### Releasing

This package uses [Changesets](https://github.com/changesets/changesets) for version management.

```bash
npx changeset           # Add a changeset after making changes
npx changeset version   # Bump version and update CHANGELOG
pnpm release            # Build and publish to npm
```

## License

MIT
