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
import { createClient } from '@spree/sdk';

// Initialize the client
const client = createClient({
  baseUrl: 'https://api.mystore.com',
  publishableKey: 'spree_pk_xxx',
});

// Browse products (Store API)
const products = await client.products.list({
  limit: 10,
  expand: ['variants', 'images'],
});

// Get a single product
const product = await client.products.get('spree-tote');

// Authentication
const { token, user } = await client.auth.login({
  email: 'customer@example.com',
  password: 'password123',
});

// Create a cart and add items
const cart = await client.cart.create();
await client.cart.items.create({
  variant_id: 'var_abc123',
  quantity: 2,
}, { spreeToken: cart.token });

// Checkout flow
await client.checkout.update({
  email: 'customer@example.com',
}, { spreeToken: cart.token });
await client.checkout.complete({ spreeToken: cart.token });
```

## Client Architecture

All Store API resources are available directly on the client:

```typescript
client.products.list()           // Products
client.cart.create()             // Cart (singleton)
client.cart.items.create(params) // Cart line items
client.carts.list()              // List active carts
client.checkout.complete(opt)    // Checkout
client.customers.create(params)  // Registration
client.customer.get(opt)         // Account
client.customer.orders.list()    // Order history
```

## Authentication

The SDK supports multiple authentication modes:

### 1. Publishable Key Only (Guest/Public Access)

```typescript
const client = createClient({
  baseUrl: 'https://api.mystore.com',
  publishableKey: 'spree_pk_xxx',
});

// Public endpoints work without user authentication
const products = await client.products.list();
```

### 2. Publishable Key + JWT (Authenticated Customer)

```typescript
// Login to get tokens
const { token, user } = await client.auth.login({
  email: 'customer@example.com',
  password: 'password123',
});

// Use token for authenticated requests
const orders = await client.customer.orders.list({}, { token });

// Refresh token when needed
const newTokens = await client.auth.refresh({ token });
```

### 3. Register New Customer

```typescript
const { token, user } = await client.customers.create({
  email: 'new@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'John',
  last_name: 'Doe',
});
```

## Guest Checkout

For guest checkout, use the `token` returned when creating a cart:

```typescript
// Create a cart (guest)
const cart = await client.cart.create();

// Use spreeToken for all cart/checkout operations
const options = { spreeToken: cart.token };

// Add items
await client.cart.items.create({
  variant_id: 'var_abc123',
  quantity: 1,
}, options);

// Update checkout with email and addresses
await client.checkout.update({
  email: 'guest@example.com',
}, options);

// Complete checkout
await client.checkout.complete(options);
```

## API Reference

### Store

```typescript
// Get current store information
const store = await client.store.get();
```

### Products

```typescript
// List products with filtering
const products = await client.products.list({
  page: 1,
  limit: 25,
  name_cont: 'shirt',
  sort: 'price asc',
  expand: ['variants', 'images', 'categories'],
});

// Get single product by ID or slug
const product = await client.products.get('spree-tote', {
  expand: ['variants', 'images'],
});

// Get available filters (price range, availability, options, categories)
const filters = await client.products.filters({
  category_id: 'ctg_abc123', // Optional: scope filters to a category
});
```

### Categories

```typescript
// List categories with filtering
const categories = await client.categories.list({
  depth_eq: 1,              // Top-level categories only
});

// Get single category by ID or permalink
const category = await client.categories.get('clothing/shirts', {
  expand: ['ancestors', 'children'], // For breadcrumbs and subcategories
});

// List products in a category
const categoryProducts = await client.categories.products.list('clothing/shirts', {
  page: 1,
  limit: 12,
  expand: ['images', 'default_variant'],
});
```

### Cart

The cart API uses an implicit cart model -- no order ID is needed. The cart is resolved
from the `spreeToken` header (guest) or JWT token (authenticated user).

```typescript
// Create a new cart
const cart = await client.cart.create();

// Get current cart
const cart = await client.cart.get({ spreeToken: cart.token });

// Delete / empty current cart
await client.cart.delete({ spreeToken: cart.token });

// Associate guest cart with authenticated user
// (after user logs in, merge their guest cart with their account)
await client.cart.associate({
  token: jwtToken,          // User's JWT token
  spreeToken: cart.token,   // Guest cart token
});

// List all active carts for authenticated user
const { data: carts } = await client.carts.list({ token: jwtToken });
```

### Cart Items (Line Items)

```typescript
const options = { spreeToken: cart.token };

// Add item
await client.cart.items.create({
  variant_id: 'var_123',
  quantity: 2,
}, options);

// Update item quantity
await client.cart.items.update(lineItemId, {
  quantity: 3,
}, options);

// Remove item
await client.cart.items.delete(lineItemId, options);
```

### Coupon Codes

```typescript
const options = { spreeToken: cart.token };

// Apply a coupon code
await client.cart.couponCodes.apply('SAVE20', options);

// Remove a coupon code
await client.cart.couponCodes.remove('promo_xxx', options);
```

### Checkout

The checkout API operates on the current cart, resolved implicitly from the
`spreeToken` header or JWT token.

```typescript
const options = { spreeToken: cart.token };

// Update checkout (email, addresses)
await client.checkout.update({
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

// Complete the order
await client.checkout.complete(options);
```

### Shipments

```typescript
const options = { spreeToken: cart.token };

// List shipments for the current checkout
const shipments = await client.checkout.shipments.list(options);

// Select a shipping rate
await client.checkout.shipments.update(shipmentId, {
  selected_shipping_rate_id: 'rate_xxx',
}, options);
```

### Store Credits

```typescript
const options = { spreeToken: cart.token };

// Apply store credit to checkout (applies maximum available by default)
await client.checkout.storeCredits.apply(undefined, options);

// Apply specific amount of store credit
await client.checkout.storeCredits.apply(25.00, options);

// Remove store credit from checkout
await client.checkout.storeCredits.remove(options);
```

### Payments

```typescript
const options = { spreeToken: cart.token };

// Get available payment methods for the current checkout
const methods = await client.checkout.paymentMethods.list(options);
// Each method includes `session_required` flag:
// - true  -> use paymentSessions (Stripe, Adyen, PayPal, etc.)
// - false -> use payments.create (Check, Cash on Delivery, Bank Transfer, etc.)

// List payments on the current checkout
const payments = await client.checkout.payments.list(options);

// Get a specific payment
const payment = await client.checkout.payments.get(paymentId, options);

// Create a payment for a non-session payment method
// (e.g. Check, Cash on Delivery, Bank Transfer, Purchase Order)
const payment = await client.checkout.payments.create({
  payment_method_id: 'pm_xxx',
  amount: '99.99',              // Optional, defaults to order total minus store credits
  metadata: {                   // Optional, write-only metadata
    purchase_order_number: 'PO-12345',
  },
}, options);
```

### Payment Sessions

Payment sessions provide a unified, provider-agnostic interface for payment processing. They work with any payment gateway (Stripe, Adyen, PayPal, etc.) through a single API.

```typescript
const options = { spreeToken: cart.token };

// Create a payment session (initializes a session with the payment gateway)
const session = await client.checkout.paymentSessions.create({
  payment_method_id: 'pm_xxx',
  amount: '99.99',             // Optional, defaults to order total
  external_data: {              // Optional, provider-specific data
    return_url: 'https://mystore.com/checkout/complete',
  },
}, options);

// The session contains provider-specific data (e.g., Stripe client_secret)
console.log(session.external_data.client_secret);

// Get a payment session
const existing = await client.checkout.paymentSessions.get(
  session.id, options
);

// Update a payment session (e.g., after order total changes)
await client.checkout.paymentSessions.update(session.id, {
  amount: '149.99',
}, options);

// Complete the payment session (after customer confirms payment on the frontend)
const completed = await client.checkout.paymentSessions.complete(
  session.id,
  { session_result: 'success' },
  options
);
console.log(completed.status); // 'completed'
```

### Orders

Completed orders can be looked up by ID or number:

```typescript
// Get a completed order by ID or number
const order = await client.orders.get('R123456789', {
  expand: ['line_items', 'shipments'],
}, { spreeToken: orderToken });
```

For order history, use the customer orders resource:

```typescript
const options = { token: jwtToken };

// List order history for authenticated customer
const orders = await client.customer.orders.list({}, options);

// Get a specific order from history
const order = await client.customer.orders.get('or_xxx', {
  expand: ['line_items', 'shipments'],
}, options);
```

### Markets

```typescript
// List all markets
const { data: markets } = await client.markets.list();
// [{ id: "mkt_xxx", name: "North America", currency: "USD", default_locale: "en", ... }]

// Get a single market
const market = await client.markets.get('mkt_xxx');

// Resolve which market applies for a country
const market = await client.markets.resolve('DE');
// => { id: "mkt_xxx", name: "Europe", currency: "EUR", default_locale: "de", ... }

// List countries in a market
const { data: countries } = await client.markets.countries.list('mkt_xxx');

// Get a country in a market (with states for address forms)
const country = await client.markets.countries.get('mkt_xxx', 'DE', {
  expand: ['states'],
});
```

### Geography

```typescript
// List countries available for checkout
const { data: countries } = await client.countries.list();

// Get country by ISO code (with states)
const usa = await client.countries.get('US', { expand: ['states'] });
console.log(usa.states); // Array of states
```

### Customer Account

```typescript
const options = { token: jwtToken };

// Get profile
const profile = await client.customer.get(options);

// Update profile
await client.customer.update({
  first_name: 'John',
  last_name: 'Doe',
}, options);
```

### Customer Addresses

```typescript
const options = { token: jwtToken };

// List addresses
const { data: addresses } = await client.customer.addresses.list({}, options);

// Get address by ID
const address = await client.customer.addresses.get('addr_xxx', options);

// Create address
await client.customer.addresses.create({
  firstname: 'John',
  lastname: 'Doe',
  address1: '123 Main St',
  city: 'New York',
  zipcode: '10001',
  country_iso: 'US',
  state_abbr: 'NY',
}, options);

// Update address
await client.customer.addresses.update('addr_xxx', { city: 'Brooklyn' }, options);

// Delete address
await client.customer.addresses.delete('addr_xxx', options);

// Mark as default billing or shipping address
await client.customer.addresses.markAsDefault('addr_xxx', 'billing', options);
await client.customer.addresses.markAsDefault('addr_xxx', 'shipping', options);
```

### Customer Credit Cards

```typescript
const options = { token: jwtToken };

// List saved credit cards
const { data: cards } = await client.customer.creditCards.list({}, options);

// Get credit card by ID
const card = await client.customer.creditCards.get('cc_xxx', options);

// Delete credit card
await client.customer.creditCards.delete('cc_xxx', options);
```

### Wishlists

```typescript
const options = { token: jwtToken };

// List wishlists
const { data: wishlists } = await client.wishlists.list({}, options);

// Get wishlist by ID
const wishlist = await client.wishlists.get('wl_xxx', {
  expand: ['wished_items'],
}, options);

// Create wishlist
const newWishlist = await client.wishlists.create({
  name: 'Birthday Ideas',
  is_private: true,
}, options);

// Update wishlist
await client.wishlists.update('wl_xxx', {
  name: 'Updated Name',
}, options);

// Delete wishlist
await client.wishlists.delete('wl_xxx', options);
```

### Wishlist Items

```typescript
const options = { token: jwtToken };

// Add item to wishlist
await client.wishlists.items.create('wl_xxx', {
  variant_id: 'var_123',
  quantity: 1,
}, options);

// Update item quantity
await client.wishlists.items.update('wl_xxx', 'wi_xxx', {
  quantity: 2,
}, options);

// Remove item from wishlist
await client.wishlists.items.delete('wl_xxx', 'wi_xxx', options);
```

## Nested Resources

The SDK uses a resource builder pattern for nested resources:

| Parent Resource | Nested Resource | Available Methods |
|-----------------|-----------------|-------------------|
| `cart` | `items` | `create`, `update`, `delete` |
| `cart` | `couponCodes` | `apply`, `remove` |
| `checkout` | `shipments` | `list`, `update` |
| `checkout` | `paymentMethods` | `list` |
| `checkout` | `payments` | `list`, `get`, `create` |
| `checkout` | `paymentSessions` | `create`, `get`, `update`, `complete` |
| `checkout` | `storeCredits` | `apply`, `remove` |
| `customer` | `addresses` | `list`, `get`, `create`, `update`, `delete`, `markAsDefault` |
| `customer` | `creditCards` | `list`, `get`, `delete` |
| `customer` | `giftCards` | `list`, `get` |
| `customer` | `orders` | `list`, `get` |
| `markets` | `countries` | `list`, `get` |
| `categories` | `products` | `list` |
| `wishlists` | `items` | `create`, `update`, `delete` |

Example:
```typescript
// Cart and checkout resources are implicit -- no order ID needed
await client.cart.items.create(params, options);
await client.cart.couponCodes.apply(code, options);
await client.checkout.shipments.update(shipmentId, params, options);
await client.checkout.payments.list(options);
await client.checkout.paymentSessions.create(params, options);
await client.checkout.storeCredits.apply(amount, options);

// Other nested resources follow the pattern: client.parent.nested.method(parentId, ...)
await client.customer.addresses.list({}, options);
await client.customer.orders.list({}, options);
await client.markets.countries.list(marketId);
await client.categories.products.list(categoryId, params, options);
await client.wishlists.items.create(wishlistId, params, options);
```

## Localization & Currency

### Client-level defaults

Set locale, currency, and country when creating the client:

```typescript
const client = createClient({
  baseUrl: 'https://api.mystore.com',
  publishableKey: 'spree_pk_xxx',
  locale: 'fr',
  currency: 'EUR',
  country: 'FR',
});

// All requests use fr/EUR/FR automatically
const products = await client.products.list();
```

Update defaults at any time:

```typescript
client.setLocale('de');
client.setCurrency('EUR');
client.setCountry('DE');
```

### Per-request overrides

Pass locale and currency headers with any request to override defaults:

```typescript
const products = await client.products.list({}, {
  locale: 'fr',
  currency: 'EUR',
  country: 'FR',
});
```

## Error Handling

```typescript
import { SpreeError } from '@spree/sdk';

try {
  await client.products.get('non-existent');
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
  StoreCart,
  StoreOrder,
  StoreVariant,
  StoreCategory,
  StoreLineItem,
  StoreAddress,
  StoreCustomer,
  PaginatedResponse,
} from '@spree/sdk';

// All responses are fully typed
const products: PaginatedResponse<StoreProduct> = await client.products.list();
const category: StoreCategory = await client.categories.get('clothing');
const cart: StoreCart = await client.cart.create();
```

## Available Types

The SDK exports all Store API types:

### Core Types
- `StoreProduct` - Product data
- `StoreVariant` - Variant data
- `StoreCart` - Cart data (uses `cart_` prefixed IDs)
- `StoreOrder` - Completed order data (uses `or_` prefixed IDs)
- `StoreLineItem` - Line item in cart
- `StoreCategory` - Category
- `StoreCountry` - Country with states
- `StoreState` - State/province
- `StoreAddress` - Customer address
- `StoreCustomer` - Customer profile
- `StoreMarket` - Market configuration (currency, locales, countries)
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
- `Client` - Main client interface
- `StoreClient` - Store API client
- `ClientConfig` - Client configuration
- `RequestOptions` - Per-request options
- `RetryConfig` - Retry behavior configuration

### Utility Types
- `PaginatedResponse<T>` - Paginated API response
- `AuthTokens` - JWT tokens from login
- `AddressParams` - Address input parameters
- `UpdateCheckoutParams` - Checkout update parameters
- `CreatePaymentParams` - Direct payment creation parameters (for non-session payment methods)
- `CreatePaymentSessionParams` - Payment session creation parameters
- `UpdatePaymentSessionParams` - Payment session update parameters
- `CompletePaymentSessionParams` - Payment session completion parameters
- `ProductFiltersResponse` - Product filters response

## Custom Fetch

You can provide a custom fetch implementation:

```typescript
import { createClient } from '@spree/sdk';

const client = createClient({
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
