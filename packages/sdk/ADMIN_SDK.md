# Spree Admin SDK

The Admin SDK provides TypeScript methods for the Spree Admin API (`/api/v3/admin`). It is accessed via the `admin` property on a `SpreeClient` instance.

## Setup

```ts
import { createSpreeClient } from '@spree/sdk'

const client = createSpreeClient({
  baseUrl: 'https://mystore.com',
  secretKey: 'spree_sk_...',
})
```

The `secretKey` is a secret API key created in the Spree admin. It is sent as `x-spree-api-key` on every request.

## Common Patterns

### Pagination

All `list` methods return a `PaginatedResponse<T>`:

```ts
interface PaginatedResponse<T> {
  data: T[]
  meta: {
    page: number
    limit: number
    count: number
    pages: number
    from: number
    to: number
    in: number
    previous: number | null
    next: number | null
  }
}
```

```ts
const { data, meta } = await client.admin.products.list({ page: 2, limit: 25 })
```

### Sorting

Pass a `sort` string. Prefix with `-` for descending:

```ts
await client.admin.orders.list({ sort: '-created_at' })
```

### Filtering (Ransack)

Filter keys are automatically wrapped in `q[...]`:

```ts
await client.admin.orders.list({ state_eq: 'complete', completed_at_gte: '2024-01-01' })
// Sends: q[state_eq]=complete&q[completed_at_gte]=2024-01-01
```

### Expanding Associations

Pass `expand` as a string array. Supports dot notation for nested expand (max 4 levels):

```ts
await client.admin.products.get('prod_abc', { expand: ['variants', 'variants.images'] })
```

### Authenticated Requests

Admin user operations require a Bearer token (from `admin.auth.login`) passed via `RequestOptions`:

```ts
const { token } = await client.admin.auth.login({
  email: 'admin@example.com',
  password: 'password',
})

await client.admin.orders.list({}, { token })
```

### Idempotency

Mutating requests accept an `idempotencyKey` for safe retries:

```ts
await client.admin.orders.create(params, { token, idempotencyKey: 'unique-key-123' })
```

### Prefixed IDs

All IDs in the Admin API use Stripe-style prefixed IDs (e.g., `prod_86Rf07xd4z`, `or_m3Rp9wXz`). Use these prefixed IDs in all method parameters.

---

## Authentication

### `admin.auth.login(credentials)`

Login with email and password. Returns a JWT token for subsequent requests.

```ts
const { token, user } = await client.admin.auth.login({
  email: 'admin@example.com',
  password: 'password',
  provider: 'spree',  // optional
})
```

**Response:** `AdminAuthTokens`

| Field | Type | Description |
|-------|------|-------------|
| `token` | `string` | JWT Bearer token |
| `user.id` | `string` | Admin user prefixed ID |
| `user.email` | `string` | Admin email |
| `user.first_name` | `string \| null` | |
| `user.last_name` | `string \| null` | |
| `user.created_at` | `string` | |
| `user.updated_at` | `string` | |

### `admin.auth.refresh(options)`

Refresh an access token. Requires a valid Bearer token.

```ts
const newTokens = await client.admin.auth.refresh({ token: currentToken })
```

---

## Products

### `admin.products.list(params?, options?)`

List products with pagination, sorting, and filtering.

```ts
const products = await client.admin.products.list({
  page: 1,
  limit: 25,
  sort: '-created_at',
  expand: ['variants'],
}, { token })
```

### `admin.products.get(id, params?, options?)`

Get a single product.

```ts
const product = await client.admin.products.get('prod_abc', {
  expand: ['variants', 'variants.images', 'taxons', 'option_types'],
}, { token })
```

### `admin.products.create(params, options?)`

Create a product.

```ts
const product = await client.admin.products.create({
  name: 'T-Shirt',
  price: 29.99,
  shipping_category_id: 'sc_abc',
  description: 'A comfortable t-shirt',
  status: 'draft',
  sku: 'TSHIRT-001',
  tax_category_id: 'tc_xyz',
  taxon_ids: ['taxon_abc', 'taxon_def'],
  tags: ['new', 'summer'],
  variants: [
    {
      sku: 'TSHIRT-S',
      price: 29.99,
      options: [
        { name: 'size', value: 'Small' },
        { name: 'color', value: 'Red' },
      ],
      prices: [
        { currency: 'USD', amount: 29.99 },
        { currency: 'EUR', amount: 27.99 },
      ],
      stock_items: [
        { location_id: 'loc_abc', quantity: 10, backorderable: true },
      ],
    },
  ],
}, { token })
```

**Params:** `AdminProductCreateParams`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | yes | |
| `price` | `number` | yes | Default price (master variant) |
| `shipping_category_id` | `string` | yes | Prefixed ID |
| `description` | `string` | no | |
| `slug` | `string` | no | Auto-generated from name if omitted |
| `status` | `'draft' \| 'active' \| 'archived'` | no | Defaults to `draft` |
| `sku` | `string` | no | Master variant SKU |
| `tax_category_id` | `string` | no | Prefixed ID |
| `taxon_ids` | `string[]` | no | Prefixed IDs |
| `tags` | `string[]` | no | |
| `variants` | `array` | no | Inline variant creation (see below) |

**Inline variant params:**

| Field | Type | Description |
|-------|------|-------------|
| `sku` | `string` | |
| `price` | `number` | |
| `option_type` | `string` | Auto-created if needed |
| `option_value` | `string` | Auto-created if needed |
| `total_on_hand` | `number` | |
| `prices` | `array` | `{ currency, amount, compare_at_amount? }` |

### `admin.products.update(id, params, options?)`

Update a product.

```ts
await client.admin.products.update('prod_abc', {
  name: 'Updated T-Shirt',
  status: 'active',
  tags: ['sale'],
}, { token })
```

**Params:** `AdminProductUpdateParams` — same fields as create, all optional.

### `admin.products.delete(id, options?)`

Soft-delete a product.

```ts
await client.admin.products.delete('prod_abc', { token })
```

**Response:** `void` (204 No Content)

### Response Type: `AdminProduct`

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` | Prefixed ID (e.g., `prod_abc`) |
| `name` | `string` | |
| `description` | `string \| null` | |
| `slug` | `string` | |
| `status` | `string` | `draft`, `active`, or `archived` |
| `variant_count` | `number` | Number of non-master variants |
| `available_on` | `string \| null` | ISO 8601 timestamp |
| `make_active_at` | `string \| null` | |
| `discontinue_on` | `string \| null` | |
| `purchasable` | `boolean` | |
| `in_stock` | `boolean` | |
| `backorderable` | `boolean` | |
| `available` | `boolean` | |
| `promotionable` | `boolean` | |
| `default_variant_id` | `string` | Prefixed ID |
| `thumbnail_url` | `string \| null` | |
| `tags` | `string[]` | |
| `price` | `AdminPrice` | Default variant price |
| `original_price` | `AdminPrice \| null` | Compare-at price |
| `shipping_category_id` | `string \| null` | |
| `tax_category_id` | `string \| null` | |
| `cost_price` | `string \| null` | |
| `cost_currency` | `string \| null` | |
| `meta_title` | `string \| null` | |
| `meta_description` | `string \| null` | |
| `meta_keywords` | `string \| null` | |
| `deleted_at` | `string \| null` | |
| `created_at` | `string` | |
| `updated_at` | `string` | |
| `variants?` | `AdminVariant[]` | Requires `expand: ['variants']` |
| `default_variant?` | `AdminVariant` | Requires expand |
| `master_variant?` | `AdminVariant` | Requires expand |
| `images?` | `AdminImage[]` | Requires expand |
| `option_types?` | `AdminOptionType[]` | Requires expand |
| `taxons?` | `AdminTaxon[]` | Requires expand |
| `metafields?` | `AdminMetafield[]` | Requires expand |
| `shipping_category?` | `AdminShippingCategory` | Requires expand |
| `tax_category?` | `AdminTaxCategory` | Requires expand |

---

## Product Variants

Nested under `admin.products.variants`.

### `admin.products.variants.list(productId, params?, options?)`

```ts
const variants = await client.admin.products.variants.list('prod_abc', {
  expand: ['images', 'prices', 'stock_items'],
}, { token })
```

### `admin.products.variants.get(productId, id, params?, options?)`

```ts
const variant = await client.admin.products.variants.get(
  'prod_abc',
  'variant_xyz',
  { expand: ['prices', 'stock_items'] },
  { token },
)
```

### `admin.products.variants.create(productId, params, options?)`

```ts
const variant = await client.admin.products.variants.create('prod_abc', {
  sku: 'TSHIRT-L',
  price: 29.99,
  options: [{ name: 'Size', value: 'Large' }],
  track_inventory: true,
  prices: [
    { currency: 'USD', amount: 29.99, compare_at_amount: 39.99 },
    { currency: 'EUR', amount: 27.99 },
  ],
  stock_items: [
    { stock_location_id: 'sl_abc', count_on_hand: 50, backorderable: false },
  ],
}, { token })
```

**Params:** `AdminVariantCreateParams`

| Field | Type | Description |
|-------|------|-------------|
| `sku` | `string` | |
| `price` | `number` | Default currency price |
| `compare_at_price` | `number` | |
| `cost_price` | `number` | |
| `cost_currency` | `string` | |
| `weight` | `number` | |
| `height` | `number` | |
| `width` | `number` | |
| `depth` | `number` | |
| `weight_unit` | `string` | `g`, `kg`, `lb`, `oz` |
| `dimensions_unit` | `string` | `mm`, `cm`, `in`, `ft` |
| `track_inventory` | `boolean` | |
| `tax_category_id` | `string` | Prefixed ID |
| `position` | `number` | |
| `barcode` | `string` | |
| `prices` | `array` | Multi-currency prices (upserted by currency) |
| `stock_items` | `array` | Multi-location stock (upserted by location) |

**Nested prices:**

| Field | Type | Required |
|-------|------|----------|
| `currency` | `string` | yes |
| `amount` | `number` | yes |
| `compare_at_amount` | `number` | no |

**Nested stock_items:**

| Field | Type | Description |
|-------|------|-------------|
| `stock_location_id` | `string` | Prefixed ID |
| `count_on_hand` | `number` | |
| `backorderable` | `boolean` | |

### `admin.products.variants.update(productId, id, params, options?)`

```ts
await client.admin.products.variants.update('prod_abc', 'variant_xyz', {
  sku: 'TSHIRT-L-UPDATED',
  prices: [{ currency: 'USD', amount: 34.99 }],
}, { token })
```

**Params:** `AdminVariantUpdateParams` — same fields as create, all optional.

### `admin.products.variants.delete(productId, id, options?)`

Soft-delete a variant.

```ts
await client.admin.products.variants.delete('prod_abc', 'variant_xyz', { token })
```

### Response Type: `AdminVariant`

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` | Prefixed ID |
| `product_id` | `string` | |
| `sku` | `string \| null` | |
| `is_master` | `boolean` | |
| `options_text` | `string` | e.g., `"Size: Large, Color: Red"` |
| `track_inventory` | `boolean` | |
| `position` | `number` | |
| `purchasable` | `boolean` | |
| `in_stock` | `boolean` | |
| `backorderable` | `boolean` | |
| `weight` | `number \| null` | |
| `height` | `number \| null` | |
| `width` | `number \| null` | |
| `depth` | `number \| null` | |
| `weight_unit` | `string \| null` | |
| `dimensions_unit` | `string \| null` | |
| `barcode` | `string \| null` | |
| `cost_price` | `string \| null` | |
| `cost_currency` | `string \| null` | |
| `tax_category_id` | `string \| null` | |
| `total_on_hand` | `number \| null` | |
| `thumbnail` | `string \| null` | Image URL |
| `image_count` | `number` | |
| `price` | `AdminPrice` | Default currency price |
| `original_price` | `AdminPrice \| null` | Compare-at price |
| `option_values` | `AdminOptionValue[]` | Always included |
| `deleted_at` | `string \| null` | |
| `discontinue_on` | `string \| null` | |
| `created_at` | `string` | |
| `updated_at` | `string` | |
| `images?` | `AdminImage[]` | Requires expand |
| `prices?` | `AdminPrice[]` | Requires expand |
| `stock_items?` | `AdminStockItem[]` | Requires expand |
| `product?` | `AdminProduct` | Requires expand |
| `metafields?` | `AdminMetafield[]` | Requires expand |
| `tax_category?` | `AdminTaxCategory` | Requires expand |

---

## Product Assets

Nested under `admin.products.assets`. Manages images and other media for the product's master variant.

### `admin.products.assets.list(productId, params?, options?)`

### `admin.products.assets.create(productId, params, options?)`

```ts
await client.admin.products.assets.create('prod_abc', {
  url: 'https://example.com/image.jpg',
  alt: 'Product front view',
  position: 1,
  type: 'Spree::Image',
}, { token })
```

**Params:** `AdminAssetCreateParams`

| Field | Type | Description |
|-------|------|-------------|
| `url` | `string` | URL of the image |
| `alt` | `string` | Alt text |
| `position` | `number` | Sort order |
| `type` | `string` | Asset type (e.g., `Spree::Image`) |

### `admin.products.assets.update(productId, id, params, options?)`

### `admin.products.assets.delete(productId, id, options?)`

---

## Variant Assets

Nested under `admin.products.variants.assets`. Same interface as product assets, scoped to a specific variant.

### `admin.products.variants.assets.list(productId, variantId, params?, options?)`

### `admin.products.variants.assets.create(productId, variantId, params, options?)`

### `admin.products.variants.assets.update(productId, variantId, id, params, options?)`

### `admin.products.variants.assets.delete(productId, variantId, id, options?)`

---

## Option Types

### `admin.optionTypes.list(params?, options?)`

```ts
const optionTypes = await client.admin.optionTypes.list({}, { token })
```

### `admin.optionTypes.get(id, params?, options?)`

```ts
const optionType = await client.admin.optionTypes.get('ot_abc', {
  expand: ['metafields'],
}, { token })
```

### `admin.optionTypes.create(params, options?)`

```ts
const optionType = await client.admin.optionTypes.create({
  name: 'size',
  presentation: 'Size',
  position: 1,
  filterable: true,
  option_values: [
    { name: 'small', presentation: 'S', position: 1 },
    { name: 'medium', presentation: 'M', position: 2 },
    { name: 'large', presentation: 'L', position: 3 },
  ],
}, { token })
```

**Params:** `AdminOptionTypeCreateParams`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | yes | Internal name |
| `presentation` | `string` | yes | Display name |
| `position` | `number` | no | Sort order |
| `filterable` | `boolean` | no | Show in storefront filters |
| `option_values` | `array` | no | Inline value creation |

### `admin.optionTypes.update(id, params, options?)`

```ts
await client.admin.optionTypes.update('ot_abc', {
  presentation: 'Clothing Size',
  option_values: [
    { id: 'ov_abc', presentation: 'Small' },  // update existing
    { name: 'xl', presentation: 'XL', position: 4 },  // create new
  ],
}, { token })
```

### `admin.optionTypes.delete(id, options?)`

### Response Type: `AdminOptionType`

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` | Prefixed ID |
| `name` | `string` | |
| `presentation` | `string` | |
| `position` | `number` | |
| `filterable` | `boolean` | |
| `created_at` | `string` | |
| `updated_at` | `string` | |
| `option_values` | `AdminOptionValue[]` | Always included |
| `metafields?` | `AdminMetafield[]` | Requires expand |

---

## Orders

### `admin.orders.list(params?, options?)`

```ts
const orders = await client.admin.orders.list({
  sort: '-completed_at',
  state_eq: 'complete',
  completed_at_gte: '2024-01-01',
  expand: ['line_items'],
}, { token })
```

### `admin.orders.get(id, params?, options?)`

```ts
const order = await client.admin.orders.get('or_abc', {
  expand: ['adjustments', 'return_authorizations', 'reimbursements'],
}, { token })
```

### `admin.orders.create(params, options?)`

Create a draft order.

```ts
const order = await client.admin.orders.create({
  email: 'customer@example.com',
  user_id: 'user_abc',
  currency: 'USD',
  channel: 'admin',
  internal_note: 'Phone order',
}, { token })
```

**Params:** `AdminOrderCreateParams`

| Field | Type | Description |
|-------|------|-------------|
| `email` | `string` | Customer email |
| `user_id` | `string` | Prefixed ID, link to existing user |
| `currency` | `string` | Order currency |
| `channel` | `string` | Sales channel |
| `internal_note` | `string` | Internal staff note |

### `admin.orders.update(id, params, options?)`

```ts
await client.admin.orders.update('or_abc', {
  email: 'new@example.com',
  internal_note: 'Updated by admin',
  ship_address: {
    firstname: 'John',
    lastname: 'Doe',
    address1: '123 Main St',
    city: 'New York',
    zipcode: '10001',
    country_iso: 'US',
    state_abbr: 'NY',
    phone: '555-1234',
  },
  line_items: [
    { variant_id: 'variant_abc', quantity: 2 },
  ],
}, { token })
```

**Params:** `AdminOrderUpdateParams`

| Field | Type | Description |
|-------|------|-------------|
| `email` | `string` | |
| `special_instructions` | `string` | Customer note |
| `internal_note` | `string` | Staff note |
| `channel` | `string` | |
| `ship_address` | `object` | Shipping address |
| `bill_address` | `object` | Billing address |
| `line_items` | `array` | `{ variant_id, quantity }` |

### `admin.orders.delete(id, options?)`

Delete a draft order (only works on incomplete orders).

### `admin.orders.cancel(id, params?, options?)`

Cancel a completed order.

```ts
await client.admin.orders.cancel('or_abc', {}, { token })
```

### `admin.orders.approve(id, params?, options?)`

Approve an order.

### `admin.orders.resume(id, params?, options?)`

Resume a canceled order.

### `admin.orders.resendConfirmation(id, params?, options?)`

Resend the order confirmation email.

### Response Type: `AdminOrder`

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` | Prefixed ID |
| `number` | `string` | Order number (e.g., `R123456`) |
| `state` | `string` | `cart`, `address`, `delivery`, `payment`, `confirm`, `complete` |
| `email` | `string \| null` | |
| `currency` | `string` | |
| `item_count` | `number` | |
| `item_total` | `string` | |
| `ship_total` | `string` | |
| `tax_total` | `string` | |
| `total` | `string` | |
| `payment_total` | `string` | |
| `payment_state` | `string \| null` | `balance_due`, `paid`, `credit_owed`, etc. |
| `shipment_state` | `string \| null` | `pending`, `ready`, `shipped`, `partial` |
| `channel` | `string \| null` | |
| `internal_note` | `string \| null` | |
| `completed_at` | `string \| null` | |
| `canceled_at` | `string \| null` | |
| `approved_at` | `string \| null` | |
| `created_at` | `string` | |
| `updated_at` | `string` | |
| `line_items` | `AdminLineItem[]` | Always included |
| `shipments` | `AdminShipment[]` | Always included |
| `payments` | `AdminPayment[]` | Always included |
| `bill_address` | `StoreAddress \| null` | |
| `ship_address` | `StoreAddress \| null` | |
| `payment_methods` | `StorePaymentMethod[]` | |
| `user?` | `AdminCustomer` | Requires expand |
| `adjustments?` | `AdminAdjustment[]` | Requires expand |
| `return_authorizations?` | `AdminReturnAuthorization[]` | Requires expand |
| `reimbursements?` | `AdminReimbursement[]` | Requires expand |

---

## Order Adjustments

Nested under `admin.orders.adjustments`.

### `admin.orders.adjustments.list(orderId, params?, options?)`

### `admin.orders.adjustments.get(orderId, id, params?, options?)`

### `admin.orders.adjustments.create(orderId, params, options?)`

```ts
await client.admin.orders.adjustments.create('or_abc', {
  amount: -5.00,
  label: 'Loyalty discount',
}, { token })
```

**Params:** `AdminAdjustmentCreateParams`

| Field | Type | Required |
|-------|------|----------|
| `amount` | `number` | yes |
| `label` | `string` | yes |

### `admin.orders.adjustments.update(orderId, id, params, options?)`

**Params:** `AdminAdjustmentUpdateParams`

| Field | Type |
|-------|------|
| `amount` | `number` |
| `label` | `string` |
| `eligible` | `boolean` |

### `admin.orders.adjustments.delete(orderId, id, options?)`

---

## Order Line Items

Nested under `admin.orders.lineItems`.

### `admin.orders.lineItems.list(orderId, params?, options?)`

### `admin.orders.lineItems.get(orderId, id, params?, options?)`

### `admin.orders.lineItems.create(orderId, params, options?)`

```ts
await client.admin.orders.lineItems.create('or_abc', {
  variant_id: 'variant_xyz',
  quantity: 2,
}, { token })
```

**Params:** `AdminLineItemCreateParams`

| Field | Type | Required |
|-------|------|----------|
| `variant_id` | `string` | yes |
| `quantity` | `number` | no (defaults to 1) |

### `admin.orders.lineItems.update(orderId, id, params, options?)`

**Params:** `AdminLineItemUpdateParams` — `{ quantity?: number }`

### `admin.orders.lineItems.delete(orderId, id, options?)`

---

## Order Payments

Nested under `admin.orders.payments`.

### `admin.orders.payments.list(orderId, params?, options?)`

### `admin.orders.payments.get(orderId, id, params?, options?)`

### `admin.orders.payments.create(orderId, params, options?)`

```ts
await client.admin.orders.payments.create('or_abc', {
  payment_method_id: 'pm_xyz',
  amount: 49.99,
  source_id: 'cc_abc',
}, { token })
```

**Params:** `AdminPaymentCreateParams`

| Field | Type | Required |
|-------|------|----------|
| `payment_method_id` | `string` | yes |
| `amount` | `number` | no |
| `source_id` | `string` | no |

### `admin.orders.payments.capture(orderId, id, params?, options?)`

Capture an authorized payment.

### `admin.orders.payments.void(orderId, id, params?, options?)`

Void a pending payment.

---

## Order Refunds

Nested under `admin.orders.refunds`.

### `admin.orders.refunds.list(orderId, params?, options?)`

### `admin.orders.refunds.create(orderId, params, options?)`

```ts
await client.admin.orders.refunds.create('or_abc', {
  payment_id: 'pay_xyz',
  amount: 10.00,
  refund_reason_id: 'rr_abc',
}, { token })
```

**Params:** `AdminRefundCreateParams`

| Field | Type | Required |
|-------|------|----------|
| `payment_id` | `string` | yes |
| `amount` | `number` | yes |
| `refund_reason_id` | `string` | no |

---

## Order Shipments

Nested under `admin.orders.shipments`.

### `admin.orders.shipments.list(orderId, params?, options?)`

### `admin.orders.shipments.get(orderId, id, params?, options?)`

### `admin.orders.shipments.update(orderId, id, params, options?)`

```ts
await client.admin.orders.shipments.update('or_abc', 'ship_xyz', {
  tracking: '1Z999AA10123456784',
  selected_shipping_rate_id: 'sr_abc',
}, { token })
```

**Params:** `AdminShipmentUpdateParams`

| Field | Type |
|-------|------|
| `tracking` | `string` |
| `selected_shipping_rate_id` | `string` |

### `admin.orders.shipments.ship(orderId, id, params?, options?)`

Mark a shipment as shipped.

### `admin.orders.shipments.cancel(orderId, id, params?, options?)`

Cancel a shipment.

### `admin.orders.shipments.resume(orderId, id, params?, options?)`

Resume a canceled shipment.

### `admin.orders.shipments.split(orderId, id, params?, options?)`

Split a shipment.

---

## Taxonomies

### `admin.taxonomies.list(params?, options?)`

```ts
const taxonomies = await client.admin.taxonomies.list({
  expand: ['taxons', 'root'],
}, { token })
```

### `admin.taxonomies.get(id, params?, options?)`

### `admin.taxonomies.create(params, options?)`

```ts
const taxonomy = await client.admin.taxonomies.create({
  name: 'Categories',
  position: 1,
}, { token })
```

**Params:** `AdminTaxonomyCreateParams`

| Field | Type | Required |
|-------|------|----------|
| `name` | `string` | yes |
| `position` | `number` | no |

### `admin.taxonomies.update(id, params, options?)`

### `admin.taxonomies.delete(id, options?)`

### Response Type: `AdminTaxonomy`

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` | Prefixed ID |
| `name` | `string` | |
| `position` | `number` | |
| `store_id` | `string \| null` | |
| `root_id` | `string \| null` | Root taxon ID |
| `created_at` | `string` | |
| `updated_at` | `string` | |
| `root?` | `AdminTaxon` | Requires expand |
| `taxons?` | `AdminTaxon[]` | Requires expand |
| `metafields?` | `AdminMetafield[]` | Requires expand |

---

## Taxonomy Taxons

Nested under `admin.taxonomies.taxons`. Manages taxons within a specific taxonomy.

### `admin.taxonomies.taxons.list(taxonomyId, params?, options?)`

### `admin.taxonomies.taxons.get(taxonomyId, id, params?, options?)`

### `admin.taxonomies.taxons.create(taxonomyId, params, options?)`

```ts
const taxon = await client.admin.taxonomies.taxons.create('taxonomy_abc', {
  name: 'T-Shirts',
  parent_id: 'taxon_root',
  position: 1,
  description: 'All t-shirt products',
  meta_title: 'T-Shirts',
  hide_from_nav: false,
}, { token })
```

**Params:** `AdminTaxonCreateParams`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | yes | |
| `parent_id` | `string` | no | Prefixed ID of parent taxon |
| `position` | `number` | no | |
| `description` | `string` | no | |
| `permalink` | `string` | no | Custom URL slug |
| `meta_title` | `string` | no | |
| `meta_description` | `string` | no | |
| `meta_keywords` | `string` | no | |
| `hide_from_nav` | `boolean` | no | |
| `sort_order` | `string` | no | |

### `admin.taxonomies.taxons.update(taxonomyId, id, params, options?)`

### `admin.taxonomies.taxons.delete(taxonomyId, id, options?)`

---

## Taxons (Flat)

A flat endpoint for listing and retrieving taxons across all taxonomies.

### `admin.taxons.list(params?, options?)`

```ts
const taxons = await client.admin.taxons.list({
  expand: ['taxonomy', 'children'],
}, { token })
```

### `admin.taxons.get(id, params?, options?)`

### Response Type: `AdminTaxon`

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` | Prefixed ID |
| `name` | `string` | |
| `permalink` | `string` | URL path |
| `position` | `number` | |
| `depth` | `number` | Nesting depth (0 = root) |
| `parent_id` | `string \| null` | |
| `taxonomy_id` | `string` | |
| `description` | `string` | |
| `description_html` | `string` | |
| `image_url` | `string \| null` | |
| `square_image_url` | `string \| null` | |
| `children_count` | `number` | |
| `is_root` | `boolean` | |
| `is_child` | `boolean` | |
| `is_leaf` | `boolean` | |
| `hide_from_nav` | `boolean` | |
| `sort_order` | `string` | |
| `automatic` | `boolean` | Auto-matching rules |
| `rules_match_policy` | `string` | |
| `lft` | `number` | Nested set left |
| `rgt` | `number` | Nested set right |
| `meta_title` | `string \| null` | |
| `meta_description` | `string \| null` | |
| `meta_keywords` | `string \| null` | |
| `created_at` | `string` | |
| `updated_at` | `string` | |
| `parent?` | `AdminTaxon` | Requires expand |
| `children?` | `AdminTaxon[]` | Requires expand |
| `ancestors?` | `AdminTaxon[]` | Requires expand |
| `taxonomy?` | `AdminTaxonomy` | Requires expand |
| `metafields?` | `AdminMetafield[]` | Requires expand |

---

## Error Handling

All methods throw `SpreeError` on failure:

```ts
import { SpreeError } from '@spree/sdk'

try {
  await client.admin.products.get('prod_nonexistent', {}, { token })
} catch (error) {
  if (error instanceof SpreeError) {
    console.log(error.code)     // 'not_found'
    console.log(error.status)   // 404
    console.log(error.message)  // "Couldn't find Spree::Product..."
    console.log(error.details)  // { field: ['message'] } for validation errors
  }
}
```

### Error Response Shape

```ts
interface ErrorResponse {
  error: {
    code: string       // 'not_found', 'validation_error', 'unauthorized', etc.
    message: string
    details?: Record<string, string[]>  // field-level errors for 422s
  }
}
```

Common error codes:

| Code | Status | Description |
|------|--------|-------------|
| `unauthorized` | 401 | Missing or invalid API key / token |
| `forbidden` | 403 | Insufficient permissions |
| `not_found` | 404 | Resource not found |
| `validation_error` | 422 | Invalid params (see `details` for fields) |
| `conflict` | 409 | Idempotency key conflict |
