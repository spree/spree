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
  apiKey: 'your-publishable-api-key',
});

// Browse products
const products = await client.products.list({
  per_page: 10,
  includes: 'variants,images',
});

// Get a single product
const product = await client.products.get('ruby-on-rails-tote');

// Authentication
const tokens = await client.auth.login({
  email: 'customer@example.com',
  password: 'password123',
});

// Create a cart and add items
const cart = await client.orders.create();
await client.orders.lineItems.create(cart.id, {
  variant_id: 'var_abc123',
  quantity: 2,
}, { orderToken: cart.order_token });

// Checkout flow
await client.orders.next(cart.id, { orderToken: cart.order_token });
await client.orders.complete(cart.id, { orderToken: cart.order_token });
```

## Authentication

The SDK supports two authentication modes:

### 1. API Key Only (Guest/Public Access)

```typescript
const client = createSpreeClient({
  baseUrl: 'https://api.mystore.com',
  apiKey: 'pk_your-publishable-key',
});

// Public endpoints work without authentication
const products = await client.products.list();
```

### 2. API Key + JWT (Authenticated Customer)

```typescript
// Login to get tokens
const tokens = await client.auth.login({
  email: 'customer@example.com',
  password: 'password123',
});

// Use token for authenticated requests
const orders = await client.orders.list({}, { token: tokens.access_token });

// Refresh token when needed
const newTokens = await client.auth.refresh(tokens.refresh_token);
```

## Guest Checkout

For guest checkout, use the `order_token` returned when creating an order:

```typescript
// Create a cart (guest)
const cart = await client.orders.create();

// Use orderToken for all cart operations
const options = { orderToken: cart.order_token };

// Add items
await client.orders.lineItems.create(cart.id, {
  variant_id: 'var_abc123',
  quantity: 1,
}, options);

// Update order with email
await client.orders.update(cart.id, {
  email: 'guest@example.com',
}, options);

// Complete checkout
await client.orders.complete(cart.id, options);
```

## API Reference

### Products

```typescript
// List products with filtering
const products = await client.products.list({
  page: 1,
  per_page: 25,
  'q[name_cont]': 'shirt',
  includes: 'variants,images,taxons',
});

// Get single product by ID or slug
const product = await client.products.get('ruby-on-rails-tote', {
  includes: 'variants,images',
});
```

### Categories (Taxonomies & Taxons)

```typescript
// List taxonomies
const taxonomies = await client.taxonomies.list({
  includes: 'taxons',
});

// Get taxonomy with taxons
const categories = await client.taxonomies.get('tax_123', {
  includes: 'root,taxons',
});

// List taxons with filtering
const taxons = await client.taxons.list({
  'q[depth_eq]': 1,           // Top-level categories only
  'q[taxonomy_id_eq]': '123', // Filter by taxonomy
});

// Get single taxon by ID or permalink
const taxon = await client.taxons.get('categories/clothing', {
  includes: 'ancestors,children', // For breadcrumbs and subcategories
});

// List products in a category
const categoryProducts = await client.taxons.products.list('categories/clothing', {
  page: 1,
  per_page: 12,
  includes: 'images,default_variant',
});
```

### Cart & Checkout

```typescript
// Create cart
const cart = await client.orders.create();
const options = { orderToken: cart.order_token };

// Add item
await client.orders.lineItems.create(cart.id, {
  variant_id: 'var_123',
  quantity: 2,
}, options);

// Update item quantity
await client.orders.lineItems.update(cart.id, lineItemId, {
  quantity: 3,
}, options);

// Remove item
await client.orders.lineItems.delete(cart.id, lineItemId, options);

// Update order (email, addresses)
await client.orders.update(cart.id, {
  email: 'customer@example.com',
  bill_address_attributes: {
    firstname: 'John',
    lastname: 'Doe',
    address1: '123 Main St',
    city: 'New York',
    zipcode: '10001',
    phone: '+1 555 123 4567',
    country_iso: 'US',
  },
}, options);

// Checkout flow
await client.orders.next(cart.id, options);     // Move to next step
await client.orders.advance(cart.id, options);  // Advance through all steps
await client.orders.complete(cart.id, options); // Complete the order
```

### Payments

```typescript
const options = { orderToken: cart.order_token };

// Get available payment methods for an order
const methods = await client.orders.paymentMethods.list(cart.id, options);

// List payments on an order
const payments = await client.orders.payments.list(cart.id, options);

// Get a specific payment
const payment = await client.orders.payments.get(cart.id, paymentId, options);
```

### Geography

```typescript
// List countries available for checkout
const countries = await client.countries.list();

// Get country by ISO code (includes states)
const usa = await client.countries.get('US');
console.log(usa.states); // Array of states
```

### Customer Account

```typescript
const options = { token: tokens.access_token };

// Get profile
const profile = await client.customer.get(options);

// Update profile
await client.customer.update({
  first_name: 'John',
  last_name: 'Doe',
}, options);

// Manage addresses (nested under customer)
const addresses = await client.customer.addresses.list({}, options);
await client.customer.addresses.create({
  firstname: 'John',
  lastname: 'Doe',
  address1: '123 Main St',
  city: 'New York',
  zipcode: '10001',
  country_iso: 'US',
}, options);
await client.customer.addresses.update(addressId, { city: 'Brooklyn' }, options);
await client.customer.addresses.delete(addressId, options);
```

### Wishlists

```typescript
const options = { token: tokens.access_token };

// List wishlists
const wishlists = await client.wishlists.list({}, options);

// Create wishlist
const wishlist = await client.wishlists.create({
  name: 'Birthday Ideas',
  is_private: true,
}, options);

// Manage wishlist items (nested under wishlists)
await client.wishlists.items.create(wishlist.id, {
  variant_id: 'var_123',
  quantity: 1,
}, options);

await client.wishlists.items.update(wishlist.id, itemId, {
  quantity: 2,
}, options);

await client.wishlists.items.delete(wishlist.id, itemId, options);

// Delete wishlist
await client.wishlists.delete(wishlist.id, options);
```

## Nested Resources

The SDK uses a resource builder pattern (similar to Stripe) for nested resources:

| Parent Resource | Nested Resource | Available Methods |
|-----------------|-----------------|-------------------|
| `orders` | `lineItems` | `create`, `update`, `delete` |
| `orders` | `payments` | `list`, `get` |
| `orders` | `paymentMethods` | `list` |
| `customer` | `addresses` | `list`, `get`, `create`, `update`, `delete` |
| `taxons` | `products` | `list` |
| `wishlists` | `items` | `create`, `update`, `delete` |

Example:
```typescript
// Nested resources follow the pattern: client.parent.nested.method(parentId, ...)
await client.orders.lineItems.create(orderId, params, options);
await client.orders.payments.list(orderId, options);
await client.customer.addresses.list(options);
await client.taxons.products.list(taxonId, params, options);
await client.wishlists.items.create(wishlistId, params, options);
```

## Localization & Currency

Pass locale and currency headers with any request:

```typescript
// Set locale and currency per request
const products = await client.products.list({}, {
  locale: 'fr',
  currency: 'EUR',
});

// Works with all endpoints
const taxon = await client.taxons.get('categories/clothing', {
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
  StoreOrder,
  StoreVariant,
  StoreTaxon,
  StoreTaxonomy,
  StoreLineItem,
  PaginatedResponse,
} from '@spree/sdk';

// All responses are fully typed
const products: PaginatedResponse<StoreProduct> = await client.products.list();
const taxon: StoreTaxon = await client.taxons.get('clothing');
```

## Available Types

The SDK exports all Store API types:

- `StoreProduct` - Product data
- `StoreVariant` - Variant data
- `StoreOrder` - Order/cart data
- `StoreLineItem` - Line item in cart
- `StoreTaxonomy` - Category group
- `StoreTaxon` - Individual category
- `StoreCountry` - Country with states
- `StoreAddress` - Customer address
- `StoreUser` - Customer profile
- `StoreWishlist` - Wishlist
- `StoreWishedItem` - Wishlist item
- `StorePayment` - Payment record
- `StorePaymentMethod` - Payment method
- `StoreStore` - Store configuration
- `PaginatedResponse<T>` - Paginated API response
- `AuthTokens` - JWT tokens from login

## License

BSD-3-Clause
