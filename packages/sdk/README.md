# @spree/sdk

Official TypeScript SDK for Spree Commerce API v3.

## Installation

```bash
npm install @spree/sdk
# or
yarn add @spree/sdk
# or
pnpm add @spree/sdk
```

## Quick Start

```typescript
import { createSpreeClient } from '@spree/sdk';

// Initialize the client
const client = createSpreeClient({
  baseUrl: 'https://api.mystore.com',
  publishableKey: 'spree_pk_xxx',   // Store API
  secretKey: 'spree_sk_xxx',        // Admin API (optional)
});

// Browse products (Store API)
const products = await client.store.products.list({
  per_page: 10,
  includes: 'variants,images',
});

// Get a single product
const product = await client.store.products.get('ruby-on-rails-tote');

// Authentication
const { token, user } = await client.store.auth.login({
  email: 'customer@example.com',
  password: 'password123',
});

// Create a cart and add items
const cart = await client.store.cart.create();
await client.store.orders.lineItems.create(cart.id, {
  variant_id: 'var_abc123',
  quantity: 2,
}, { orderToken: cart.token });

// Checkout flow
await client.store.orders.next(cart.id, { orderToken: cart.token });
await client.store.orders.complete(cart.id, { orderToken: cart.token });
```

## Client Architecture

The SDK exposes two API namespaces:

```typescript
client.store   // Store API — customer-facing (products, cart, checkout, account)
client.admin   // Admin API — administrative (coming soon)
```

All Store API endpoints live under `client.store.*`. The Admin API namespace is ready for future endpoints.

## Authentication

The SDK supports multiple authentication modes:

### 1. Publishable Key Only (Guest/Public Access)

```typescript
const client = createSpreeClient({
  baseUrl: 'https://api.mystore.com',
  publishableKey: 'spree_pk_xxx',
});

// Public endpoints work without user authentication
const products = await client.store.products.list();
```

### 2. Publishable Key + JWT (Authenticated Customer)

```typescript
// Login to get tokens
const { token, user } = await client.store.auth.login({
  email: 'customer@example.com',
  password: 'password123',
});

// Use token for authenticated requests
const orders = await client.store.orders.list({}, { token });

// Refresh token when needed
const newTokens = await client.store.auth.refresh({ token });
```

### 3. Register New Customer

```typescript
const { token, user } = await client.store.auth.register({
  email: 'new@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'John',
  last_name: 'Doe',
});
```

## Guest Checkout

For guest checkout, use the `token` (or `order_token`) returned when creating a cart:

```typescript
// Create a cart (guest)
const cart = await client.store.cart.create();

// Use orderToken for all cart operations
const options = { orderToken: cart.token };

// Add items
await client.store.orders.lineItems.create(cart.id, {
  variant_id: 'var_abc123',
  quantity: 1,
}, options);

// Update order with email
await client.store.orders.update(cart.id, {
  email: 'guest@example.com',
}, options);

// Complete checkout
await client.store.orders.complete(cart.id, options);
```

## API Reference

### Store

```typescript
// Get current store information
const store = await client.store.store.get();
```

### Products

```typescript
// List products with filtering
const products = await client.store.products.list({
  page: 1,
  per_page: 25,
  'q[name_cont]': 'shirt',
  includes: 'variants,images,taxons',
});

// Get single product by ID or slug
const product = await client.store.products.get('ruby-on-rails-tote', {
  includes: 'variants,images',
});

// Get available filters (price range, availability, options, taxons)
const filters = await client.store.products.filters({
  taxon_id: 'txn_abc123', // Optional: scope filters to a taxon
});
```

### Categories (Taxonomies & Taxons)

```typescript
// List taxonomies
const taxonomies = await client.store.taxonomies.list({
  includes: 'taxons',
});

// Get taxonomy with taxons
const categories = await client.store.taxonomies.get('tax_123', {
  includes: 'root,taxons',
});

// List taxons with filtering
const taxons = await client.store.taxons.list({
  'q[depth_eq]': 1,           // Top-level categories only
  'q[taxonomy_id_eq]': '123', // Filter by taxonomy
});

// Get single taxon by ID or permalink
const taxon = await client.store.taxons.get('categories/clothing', {
  includes: 'ancestors,children', // For breadcrumbs and subcategories
});

// List products in a category
const categoryProducts = await client.store.taxons.products.list('categories/clothing', {
  page: 1,
  per_page: 12,
  includes: 'images,default_variant',
});
```

### Cart

```typescript
// Get current cart
const cart = await client.store.cart.get({ orderToken: 'xxx' });

// Create a new cart
const newCart = await client.store.cart.create();

// Associate guest cart with authenticated user
// (after user logs in, merge their guest cart with their account)
await client.store.cart.associate({
  token: jwtToken,        // User's JWT token
  orderToken: cart.token, // Guest cart token
});
```

### Orders & Checkout

```typescript
// List orders for authenticated customer
const orders = await client.store.orders.list({}, { token });

// Create a new order (cart)
const cart = await client.store.orders.create();
const options = { orderToken: cart.order_token };

// Get order by ID or number
const order = await client.store.orders.get('R123456789', {
  includes: 'line_items,shipments',
}, options);

// Update order (email, addresses)
await client.store.orders.update(cart.id, {
  email: 'customer@example.com',
  ship_address: {
    firstname: 'John',
    lastname: 'Doe',
    address1: '123 Main St',
    city: 'New York',
    zipcode: '10001',
    phone: '+1 555 123 4567',
    country_iso: 'US',
    state_abbr: 'NY',
  },
  bill_address_id: 'addr_xxx', // Or use existing address by ID
}, options);

// Checkout flow
await client.store.orders.next(cart.id, options);     // Move to next step
await client.store.orders.advance(cart.id, options);  // Advance through all steps
await client.store.orders.complete(cart.id, options); // Complete the order
```

### Line Items

```typescript
const options = { orderToken: cart.token };

// Add item
await client.store.orders.lineItems.create(cart.id, {
  variant_id: 'var_123',
  quantity: 2,
}, options);

// Update item quantity
await client.store.orders.lineItems.update(cart.id, lineItemId, {
  quantity: 3,
}, options);

// Remove item
await client.store.orders.lineItems.delete(cart.id, lineItemId, options);
```

### Coupon Codes

```typescript
const options = { orderToken: cart.token };

// Apply a coupon code
await client.store.orders.couponCodes.apply(cart.id, 'SAVE20', options);

// Remove a coupon code
await client.store.orders.couponCodes.remove(cart.id, 'promo_xxx', options);
```

### Store Credits

```typescript
const options = { orderToken: cart.token };

// Apply store credit to order (applies maximum available by default)
await client.store.orders.addStoreCredit(cart.id, undefined, options);

// Apply specific amount of store credit
await client.store.orders.addStoreCredit(cart.id, 25.00, options);

// Remove store credit from order
await client.store.orders.removeStoreCredit(cart.id, options);
```

### Shipments

```typescript
const options = { orderToken: cart.token };

// List shipments for an order
const shipments = await client.store.orders.shipments.list(cart.id, options);

// Select a shipping rate
await client.store.orders.shipments.update(cart.id, shipmentId, {
  selected_shipping_rate_id: 'rate_xxx',
}, options);
```

### Payments

```typescript
const options = { orderToken: cart.token };

// Get available payment methods for an order
const methods = await client.store.orders.paymentMethods.list(cart.id, options);

// List payments on an order
const payments = await client.store.orders.payments.list(cart.id, options);

// Get a specific payment
const payment = await client.store.orders.payments.get(cart.id, paymentId, options);
```

### Payment Sessions

Payment sessions provide a unified, provider-agnostic interface for payment processing. They work with any payment gateway (Stripe, Adyen, PayPal, etc.) through a single API.

```typescript
const options = { orderToken: cart.token };

// Create a payment session (initializes a session with the payment gateway)
const session = await client.store.orders.paymentSessions.create(cart.id, {
  payment_method_id: 'pm_xxx',
  amount: '99.99',             // Optional, defaults to order total
  external_data: {              // Optional, provider-specific data
    return_url: 'https://mystore.com/checkout/complete',
  },
}, options);

// The session contains provider-specific data (e.g., Stripe client_secret)
console.log(session.external_data.client_secret);

// Get a payment session
const existing = await client.store.orders.paymentSessions.get(
  cart.id, session.id, options
);

// Update a payment session (e.g., after order total changes)
await client.store.orders.paymentSessions.update(cart.id, session.id, {
  amount: '149.99',
}, options);

// Complete the payment session (after customer confirms payment on the frontend)
const completed = await client.store.orders.paymentSessions.complete(
  cart.id, session.id,
  { session_result: 'success' },
  options
);
console.log(completed.status); // 'completed'
```

### Geography

```typescript
// List countries available for checkout
const { data: countries } = await client.store.countries.list();

// Get country by ISO code (includes states)
const usa = await client.store.countries.get('US');
console.log(usa.states); // Array of states
```

### Customer Account

```typescript
const options = { token: jwtToken };

// Get profile
const profile = await client.store.customer.get(options);

// Update profile
await client.store.customer.update({
  first_name: 'John',
  last_name: 'Doe',
}, options);
```

### Customer Addresses

```typescript
const options = { token: jwtToken };

// List addresses
const { data: addresses } = await client.store.customer.addresses.list({}, options);

// Get address by ID
const address = await client.store.customer.addresses.get('addr_xxx', options);

// Create address
await client.store.customer.addresses.create({
  firstname: 'John',
  lastname: 'Doe',
  address1: '123 Main St',
  city: 'New York',
  zipcode: '10001',
  country_iso: 'US',
  state_abbr: 'NY',
}, options);

// Update address
await client.store.customer.addresses.update('addr_xxx', { city: 'Brooklyn' }, options);

// Delete address
await client.store.customer.addresses.delete('addr_xxx', options);

// Mark as default billing or shipping address
await client.store.customer.addresses.markAsDefault('addr_xxx', 'billing', options);
await client.store.customer.addresses.markAsDefault('addr_xxx', 'shipping', options);
```

### Customer Credit Cards

```typescript
const options = { token: jwtToken };

// List saved credit cards
const { data: cards } = await client.store.customer.creditCards.list({}, options);

// Get credit card by ID
const card = await client.store.customer.creditCards.get('cc_xxx', options);

// Delete credit card
await client.store.customer.creditCards.delete('cc_xxx', options);
```

### Wishlists

```typescript
const options = { token: jwtToken };

// List wishlists
const { data: wishlists } = await client.store.wishlists.list({}, options);

// Get wishlist by ID
const wishlist = await client.store.wishlists.get('wl_xxx', {
  includes: 'wished_items',
}, options);

// Create wishlist
const newWishlist = await client.store.wishlists.create({
  name: 'Birthday Ideas',
  is_private: true,
}, options);

// Update wishlist
await client.store.wishlists.update('wl_xxx', {
  name: 'Updated Name',
}, options);

// Delete wishlist
await client.store.wishlists.delete('wl_xxx', options);
```

### Wishlist Items

```typescript
const options = { token: jwtToken };

// Add item to wishlist
await client.store.wishlists.items.create('wl_xxx', {
  variant_id: 'var_123',
  quantity: 1,
}, options);

// Update item quantity
await client.store.wishlists.items.update('wl_xxx', 'wi_xxx', {
  quantity: 2,
}, options);

// Remove item from wishlist
await client.store.wishlists.items.delete('wl_xxx', 'wi_xxx', options);
```

## Nested Resources

The SDK uses a resource builder pattern for nested resources:

| Parent Resource | Nested Resource | Available Methods |
|-----------------|-----------------|-------------------|
| `store.orders` | `lineItems` | `create`, `update`, `delete` |
| `store.orders` | `payments` | `list`, `get` |
| `store.orders` | `paymentMethods` | `list` |
| `store.orders` | `paymentSessions` | `create`, `get`, `update`, `complete` |
| `store.orders` | `shipments` | `list`, `update` |
| `store.orders` | `couponCodes` | `apply`, `remove` |
| `store.customer` | `addresses` | `list`, `get`, `create`, `update`, `delete`, `markAsDefault` |
| `store.customer` | `creditCards` | `list`, `get`, `delete` |
| `store.customer` | `giftCards` | `list`, `get` |
| `store.taxons` | `products` | `list` |
| `store.wishlists` | `items` | `create`, `update`, `delete` |

Example:
```typescript
// Nested resources follow the pattern: client.store.parent.nested.method(parentId, ...)
await client.store.orders.lineItems.create(orderId, params, options);
await client.store.orders.payments.list(orderId, options);
await client.store.orders.shipments.update(orderId, shipmentId, params, options);
await client.store.customer.addresses.list({}, options);
await client.store.taxons.products.list(taxonId, params, options);
await client.store.wishlists.items.create(wishlistId, params, options);
```

## Localization & Currency

Pass locale and currency headers with any request:

```typescript
// Set locale and currency per request
const products = await client.store.products.list({}, {
  locale: 'fr',
  currency: 'EUR',
});

// Works with all endpoints
const taxon = await client.store.taxons.get('categories/clothing', {
  includes: 'ancestors',
}, {
  locale: 'de',
  currency: 'EUR',
});
```

## Error Handling

```typescript
import { SpreeError } from '@spree/sdk';

try {
  await client.store.products.get('non-existent');
} catch (error) {
  if (error instanceof SpreeError) {
    console.log(error.code);    // 'record_not_found'
    console.log(error.message); // 'Product not found'
    console.log(error.status);  // 404
    console.log(error.details); // Validation errors (if any)
  }
}
```

## TypeScript Support

The SDK includes full TypeScript support with generated types from the API serializers:

```typescript
import type {
  StoreProduct,
  StoreOrder,
  StoreVariant,
  StoreTaxon,
  StoreTaxonomy,
  StoreLineItem,
  StoreAddress,
  StoreCustomer,
  PaginatedResponse,
} from '@spree/sdk';

// All responses are fully typed
const products: PaginatedResponse<StoreProduct> = await client.store.products.list();
const taxon: StoreTaxon = await client.store.taxons.get('clothing');
```

## Available Types

The SDK exports all Store API types:

### Core Types
- `StoreProduct` - Product data
- `StoreVariant` - Variant data
- `StoreOrder` - Order/cart data
- `StoreLineItem` - Line item in cart
- `StoreTaxonomy` - Category group
- `StoreTaxon` - Individual category
- `StoreCountry` - Country with states
- `StoreState` - State/province
- `StoreAddress` - Customer address
- `StoreCustomer` - Customer profile
- `StoreStore` - Store configuration

### Commerce Types
- `StorePayment` - Payment record
- `StorePaymentMethod` - Payment method
- `StorePaymentSession` - Provider-agnostic payment session
- `StoreShipment` - Shipment record
- `StoreShippingRate` - Shipping rate option
- `StoreShippingMethod` - Shipping method
- `StoreCreditCard` - Saved credit card
- `StoreGiftCard` - Gift card

### Product Types
- `StoreImage` - Product image
- `StorePrice` - Price data
- `StoreOptionType` - Option type (e.g., Size, Color)
- `StoreOptionValue` - Option value (e.g., Small, Red)
- `StoreDigitalLink` - Digital download link

### Wishlist Types
- `StoreWishlist` - Wishlist
- `StoreWishedItem` - Wishlist item

### Client Types
- `SpreeClient` - Main client class
- `StoreClient` - Store API client
- `AdminClient` - Admin API client
- `SpreeClientConfig` - Client configuration
- `RequestOptions` - Per-request options
- `RetryConfig` - Retry behavior configuration

### Utility Types
- `PaginatedResponse<T>` - Paginated API response
- `AuthTokens` - JWT tokens from login
- `AddressParams` - Address input parameters
- `CreatePaymentSessionParams` - Payment session creation parameters
- `UpdatePaymentSessionParams` - Payment session update parameters
- `CompletePaymentSessionParams` - Payment session completion parameters
- `ProductFiltersResponse` - Product filters response

## Custom Fetch

You can provide a custom fetch implementation:

```typescript
import { createSpreeClient } from '@spree/sdk';

const client = createSpreeClient({
  baseUrl: 'https://api.mystore.com',
  publishableKey: 'spree_pk_xxx',
  fetch: customFetchImplementation,
});
```

## Development

### Setup

```bash
cd sdk
npm install
```

### Scripts

| Command | Description |
|---------|-------------|
| `npm test` | Run tests once |
| `npm run test:watch` | Run tests in watch mode |
| `npm run test:coverage` | Run tests with coverage report |
| `npm run typecheck` | Type-check with `tsc --noEmit` |
| `npm run build` | Build CJS + ESM bundles with `tsup` |
| `npm run dev` | Build in watch mode |
| `npm run console` | Interactive REPL for testing the SDK |

### Testing

Tests use [Vitest](https://vitest.dev/) with [MSW](https://mswjs.io/) (Mock Service Worker) for API mocking at the network level.

```bash
# Run all tests
npm test

# Run in watch mode during development
npm run test:watch

# Run with coverage
npm run test:coverage
```

Test files live in `tests/` and follow the structure:

- `tests/mocks/handlers.ts` - MSW request handlers with fixture data
- `tests/mocks/server.ts` - MSW server instance
- `tests/setup.ts` - Server lifecycle (listen/reset/close)
- `tests/helpers.ts` - `createTestClient()` and constants
- `tests/*.test.ts` - Test suites per resource (auth, products, orders, etc.)

To add tests for a new endpoint, add an MSW handler in `handlers.ts` and create a corresponding test file.

### Releasing

This package uses [Changesets](https://github.com/changesets/changesets) for version management and publishing.

**After making changes:**

```bash
npx changeset
```

This prompts you to select a semver bump type (patch/minor/major) and write a summary. A changeset file is created in `.changeset/`.

**How releases work:**

1. Changeset files are committed with your PR
2. When merged to `main`, a GitHub Action creates a "Version Packages" PR that bumps the version and updates the CHANGELOG
3. When that PR is merged, the package is automatically published to npm

**Manual release (if needed):**

```bash
npm run version   # Apply changesets and bump version
npm run release   # Build and publish to npm
```

## License

MIT
