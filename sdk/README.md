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
const spree = createSpreeClient({
  baseUrl: 'https://api.mystore.com',
  apiKey: 'your-publishable-api-key',
});

// Browse products
const products = await spree.products.list({
  per_page: 10,
  includes: 'variants,images',
});

// Get a single product
const product = await spree.products.get('ruby-on-rails-tote');

// Authentication
const tokens = await spree.auth.login({
  email: 'customer@example.com',
  password: 'password123',
});

// Create a cart
const cart = await spree.orders.create();

// Add items to cart
await spree.lineItems.create(cart.number, {
  variant_id: 'var_abc123',
  quantity: 2,
}, { orderToken: cart.order_token });

// Checkout flow
await spree.orders.next(cart.number, { orderToken: cart.order_token });
await spree.orders.complete(cart.number, { orderToken: cart.order_token });
```

## Authentication

The SDK supports two authentication modes:

### 1. API Key Only (Guest/Public Access)

```typescript
const spree = createSpreeClient({
  baseUrl: 'https://api.mystore.com',
  apiKey: 'pk_your-publishable-key',
});

// Public endpoints work without authentication
const products = await spree.products.list();
```

### 2. API Key + JWT (Authenticated Customer)

```typescript
// Login to get tokens
const tokens = await spree.auth.login({
  email: 'customer@example.com',
  password: 'password123',
});

// Use token for authenticated requests
const orders = await spree.orders.list({}, { token: tokens.access_token });

// Refresh token when needed
const newTokens = await spree.auth.refresh(tokens.refresh_token);
```

## Guest Checkout

For guest checkout, use the `order_token` returned when creating an order:

```typescript
// Create a cart (guest)
const cart = await spree.orders.create();

// Use orderToken for all cart operations
const options = { orderToken: cart.order_token };

// Add items
await spree.lineItems.create(cart.number, {
  variant_id: 'var_abc123',
  quantity: 1,
}, options);

// Update order with email
await spree.orders.update(cart.number, {
  email: 'guest@example.com',
}, options);

// Complete checkout
await spree.orders.complete(cart.number, options);
```

## API Reference

### Products

```typescript
// List products with filtering
const products = await spree.products.list({
  page: 1,
  per_page: 25,
  'q[name_cont]': 'shirt',
  includes: 'variants,images,taxons',
});

// Get single product by ID or slug
const product = await spree.products.get('ruby-on-rails-tote', {
  includes: 'variants,images',
});
```

### Cart & Checkout

```typescript
// Create cart
const cart = await spree.orders.create();

// Add item
await spree.lineItems.create(orderId, {
  variant_id: 'var_123',
  quantity: 2,
});

// Update item quantity
await spree.lineItems.update(orderId, lineItemId, {
  quantity: 3,
});

// Remove item
await spree.lineItems.delete(orderId, lineItemId);

// Update order (email, addresses)
await spree.orders.update(orderId, {
  email: 'customer@example.com',
  bill_address_attributes: {
    firstname: 'John',
    lastname: 'Doe',
    address1: '123 Main St',
    city: 'New York',
    zipcode: '10001',
    phone: '+1 555 123 4567',
    country_id: 'ctry_usa',
  },
});

// Checkout flow
await spree.orders.next(orderId);    // Move to next step
await spree.orders.advance(orderId); // Advance through all steps
await spree.orders.complete(orderId); // Complete the order
```

### Payments

```typescript
// Get available payment methods
const methods = await spree.paymentMethods.list(orderId);

// Create a payment
await spree.payments.create(orderId, {
  payment_method_id: 'pm_credit_card',
  source_attributes: {
    number: '4111111111111111',
    month: '12',
    year: '2025',
    verification_value: '123',
    name: 'John Doe',
  },
});
```

### Geography

```typescript
// List countries
const countries = await spree.countries.list();

// Get country by ISO code
const usa = await spree.countries.get('US');

// List states for a country
const states = await spree.states.list({ country_id: 'ctry_usa' });
```

### Categories (Taxonomies & Taxons)

```typescript
// List taxonomies
const taxonomies = await spree.taxonomies.list();

// Get taxonomy with taxons
const categories = await spree.taxonomies.get('tax_123', {
  includes: 'taxons',
});

// Get single taxon
const taxon = await spree.taxons.get('categories/clothing');
```

### Customer Account

```typescript
// Get profile
const profile = await spree.customer.get({ token });

// Update profile
await spree.customer.update({
  first_name: 'John',
  last_name: 'Doe',
}, { token });

// Manage addresses
const addresses = await spree.addresses.list({}, { token });
await spree.addresses.create({ ... }, { token });
await spree.addresses.update(addressId, { ... }, { token });
await spree.addresses.delete(addressId, { token });
```

### Wishlists

```typescript
// List wishlists
const wishlists = await spree.wishlists.list({}, { token });

// Create wishlist
const wishlist = await spree.wishlists.create({
  name: 'Birthday Ideas',
  is_private: true,
}, { token });

// Add item to wishlist
await spree.wishlists.addItem(wishlistId, {
  variant_id: 'var_123',
}, { token });

// Remove item
await spree.wishlists.removeItem(wishlistId, itemId, { token });
```

## Error Handling

```typescript
import { SpreeError } from '@spree/sdk';

try {
  await spree.products.get('non-existent');
} catch (error) {
  if (error instanceof SpreeError) {
    console.log(error.code);    // 'record_not_found'
    console.log(error.message); // 'Product not found'
    console.log(error.status);  // 404
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
  PaginatedResponse,
} from '@spree/sdk';

const products: PaginatedResponse<StoreProduct> = await spree.products.list();
```

## License

BSD-3-Clause
