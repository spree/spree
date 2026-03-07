# Admin API Implementation Plan and Conventions

Admin API should include all the features and endpoints as the current Rails Admin in `spree/admin`.

It should follow the same conventions and patterns as Store API.

All controllers should inherit from `Spree::Api::V3::Admin::ResourceController`.

API needs to be as much RESTful as possible, let's not make exceptions and not deviate from the pattern.

The goal of building this API is to provide a programmatic interface for managing Spree resources. It will be available in SDK and CLI. Later we will build a new Admin Dashboard with Vite/TanStack on top of this API to replace our current Rails Admin.

## Infrastructure (already built)

The following infrastructure is already in place and ready for use:

- **Base controllers:** `Spree::Api::V3::Admin::BaseController` and `Spree::Api::V3::Admin::ResourceController` — provide full CRUD, pagination (Pagy), Ransack filtering, CanCanCan authorization, prefixed ID lookups, and HTTP caching
- **Authentication:** Secret API keys (`spree_sk_xxx`) via `authenticate_secret_key!` and JWT tokens with `admin_api` audience using `Spree.admin_user_class`
- **Error handling:** Stripe-style error responses (see `docs/api-reference/store-api/errors.mdx`) — same format shared with Store API
- **Serializers:** Admin serializers for 9 resources already exist in `api/app/serializers/spree/api/v3/admin/` (Product, Variant, Order, Customer, Price, Metafield, Taxon, Taxonomy, LineItem) — they extend their Store API counterparts with admin-only fields
- **Dependency injection:** Admin serializers registered in `Spree::Api::Dependencies` (e.g., `Spree.api.admin_product_serializer`)
- **Routes:** No admin API routes are defined yet — all routes need to be added to `api/config/routes.rb`

## Serializers design

Admin serializers should extend their Store API counterparts and add admin-only fields. It should include all fields/attributes for each model. This is admin API for power users who need to manage all aspects of the store.

After each serializer change we need to run Typelizer to generate TypeScript types for the API.

## Most important endpoints

These endpoints will require special attention and careful design:

* **Products API** — complex nested resource (variants, prices, images, option types, taxons); needs to support bulk operations
* **Orders API** — deep nesting (line items, shipments, payments, refunds, adjustments, addresses); state machine transitions (cancel, approve, resume); special actions (resend confirmation)

## Authentication

We should follow Store API authentication conventions with a different JWT audience. Admin should use `Spree.admin_user_class` instead of `Spree.user_class`. JWT tokens should be short-lived.

Two authentication methods are supported (infrastructure already exists):

1. **Secret API keys** (`spree_sk_xxx`) — passed via `Authorization: Bearer spree_sk_xxx` header, verified with HMAC-SHA256 digest
2. **JWT tokens** — generated via auth endpoint, passed via `Authorization: Bearer <token>` header, audience set to `admin_api`

## Creating and updating resources

We should follow Rails HTTP conventions for creating and updating resources, that is `POST` for creating and `PATCH` for updating. `DELETE` for deleting.

It needs to support nested resources, eg. Product with variants.

### Products

Example product create/update params:

```json
{
  "name": "Test product",
  "tax_category_id": "taxcat_abc1234",
  "taxon_ids": [
    "taxon_abc123",
    "taxon_def456"
  ],
  "tags": [
    "eco",
    "best-seller"
  ],
  "variants": [
    {
      "option_type": "size",
      "option_value": "small",
      "total_on_hand": 10,
      "track_inventory": true,
      "width": 10.5,
      "height": 5.2,
      "depth": 2.1,
      "weight": 0.5,
      "dimensions_unit": "cm",
      "weight_unit": "kg",
      "prices": [
        {
          "currency": "USD",
          "amount": 10.99
        },
        {
          "currency": "EUR",
          "amount": 9.99
        }
      ]
    }
  ]
}
```

If there are any validation errors, the API should return a `422 Unprocessable Entity` response with a JSON body containing the errors following the Stripe-style format:

```json
{
  "error": {
    "code": "validation_error",
    "message": "Name can't be blank",
    "details": {
      "name": ["can't be blank"]
    }
  }
}
```

See `docs/api-reference/store-api/errors.mdx` for the full error conventions.

We're not using Rails nested attributes, we use flat JSON objects for nested resources. Our main goal is to keep the API simple and easy to use for non-Rails developers (our target audience are TypeScript developers).

### Orders

Can create orders with line items in one API call.

```json
{
  "currency": "USD",
  "locale": "en-US",
  "line_items": [
    {
      "variant_id": "variant_123456789",
      "quantity": 1
    },
    {
      "variant_id": "variant_987654321",
      "quantity": 2
    }
  ]
}
```

## Using services

We should use existing services for business logic actions such as:
* order create (`Spree.cart_create_service`)
* order update (`Spree.order_update_service`)
* line item create (`Spree.line_item_create_service`)
* line item update (`Spree.line_item_update_service`)
* product create (`Spree.product_create_service`) - new service needed
* product update (`Spree.product_update_service`) - new service needed
* etc

Lets try not add new services besides the product create/update services. For other controllers/operations lets use standard record.update/create methods.

If using service is needed we need to override create/update methods in the controller.

## Scoping resources

We need to scope resources to their parent, eg.

```
GET /api/v3/admin/products/prod_1234abc/variants/variant_123456789
```

Let's use the parent pattern already present in API v3.

We should avoid 3-and-more-level nesting, as much as possible.

## Ability to upload attachments

We should support uploading attachments for resources, such as product images or order documents. Attachments should be uploaded using multipart/form-data.

Attachments are stored in ActiveStorage. Special case is Product images which use a dedicated attachment model - `Spree::Asset` (which uses ActiveStorage under the hood but allows users to add `alt` and reorder the images and assign them to specific product variants).

We should enforce max file size and type restrictions on attachments.

## Response format

All responses use flat JSON (no root key wrapping). Prefixed IDs are used everywhere (e.g., `prod_86Rf07xd4z`). Association IDs also use prefixed format.

Filtering uses Ransack query params (e.g., `?q[name_cont]=shirt`). Sorting uses JSON:API format (e.g., `?sort=-created_at`).

Associations can be expanded via `?expand=variants,variants.prices` (max 4 levels deep).

## Testing

Let's start with controller tests and don't do integration tests yet until we finalize the API design. For specific attributes testing we should use serializer tests and not controller tests.

Tests should be lean, pragmatic and quick to run. Controller tests should cover known edge cases.

## TODO

Here's the endpoint list we need to implement:

### Authentication
- [ ] `POST /api/v3/admin/auth/login` — Admin user login (JWT token generation)
- [ ] `POST /api/v3/admin/auth/refresh` — Refresh JWT token
- [ ] `DELETE /api/v3/admin/auth/logout` — Invalidate JWT token

### Products (⭐ high priority)
- [x] `GET /api/v3/admin/products` — List products (with Ransack filtering, sorting, pagination)
- [x] `GET /api/v3/admin/products/:id` — Show product
- [x] `POST /api/v3/admin/products` — Create product (with nested variants, prices, taxon_ids)
- [x] `PATCH /api/v3/admin/products/:id` — Update product
- [x] `DELETE /api/v3/admin/products/:id` — Soft-delete product
- [x] `POST /api/v3/admin/products/:id/clone` — Clone product
- [ ] `PATCH /api/v3/admin/products/bulk_update` — Bulk update products (status, taxons, tags)

### Variants (nested under Products)
- [x] `GET /api/v3/admin/products/:product_id/variants` — List variants
- [x] `GET /api/v3/admin/products/:product_id/variants/:id` — Show variant
- [x] `POST /api/v3/admin/products/:product_id/variants` — Create variant (with nested prices)
- [x] `PATCH /api/v3/admin/products/:product_id/variants/:id` — Update variant
- [x] `DELETE /api/v3/admin/products/:product_id/variants/:id` — Soft-delete variant

### Prices (managed via nested variant params, no standalone endpoints needed)

### Product Assets (nested under Products)
- [x] `GET /api/v3/admin/products/:product_id/assets` — List product assets (filterable by type: image, video, etc.)
- [x] `POST /api/v3/admin/products/:product_id/assets` — Create asset. Two modes: (1) file upload via multipart/form-data, (2) URL via `source_url` param (triggers async download). Params: type, alt, position, variant_ids
- [x] `PATCH /api/v3/admin/products/:product_id/assets/:id` — Update asset (alt, position, variant assignment)
- [x] `DELETE /api/v3/admin/products/:product_id/assets/:id` — Delete asset

### Digital Assets (nested under Products)
- [ ] `GET /api/v3/admin/products/:product_id/digital_assets` — List digital assets
- [ ] `POST /api/v3/admin/products/:product_id/digital_assets` — Upload digital asset
- [ ] `PATCH /api/v3/admin/products/:product_id/digital_assets/:id` — Update digital asset
- [ ] `DELETE /api/v3/admin/products/:product_id/digital_assets/:id` — Delete digital asset

### Option Types
- [x] `GET /api/v3/admin/option_types` — List option types
- [x] `GET /api/v3/admin/option_types/:id` — Show option type
- [x] `POST /api/v3/admin/option_types` — Create option type
- [x] `PATCH /api/v3/admin/option_types/:id` — Update option type
- [x] `DELETE /api/v3/admin/option_types/:id` — Delete option type

### Option Values (nested under Option Types)
- [x] `GET /api/v3/admin/option_types/:option_type_id/option_values` — List option values
- [x] `POST /api/v3/admin/option_types/:option_type_id/option_values` — Create option value
- [x] `PATCH /api/v3/admin/option_types/:option_type_id/option_values/:id` — Update option value
- [x] `DELETE /api/v3/admin/option_types/:option_type_id/option_values/:id` — Delete option value

### Taxonomies
- [x] `GET /api/v3/admin/taxonomies` — List taxonomies
- [x] `GET /api/v3/admin/taxonomies/:id` — Show taxonomy
- [x] `POST /api/v3/admin/taxonomies` — Create taxonomy
- [x] `PATCH /api/v3/admin/taxonomies/:id` — Update taxonomy
- [x] `DELETE /api/v3/admin/taxonomies/:id` — Delete taxonomy

### Taxons (nested under Taxonomies)
- [x] `GET /api/v3/admin/taxonomies/:taxonomy_id/taxons` — List taxons
- [x] `GET /api/v3/admin/taxonomies/:taxonomy_id/taxons/:id` — Show taxon
- [x] `POST /api/v3/admin/taxonomies/:taxonomy_id/taxons` — Create taxon
- [x] `PATCH /api/v3/admin/taxonomies/:taxonomy_id/taxons/:id` — Update taxon
- [x] `DELETE /api/v3/admin/taxonomies/:taxonomy_id/taxons/:id` — Delete taxon
- [x] `PATCH /api/v3/admin/taxonomies/:taxonomy_id/taxons/:id/reposition` — Reposition taxon in tree

### Taxons (flat, top-level for convenience)
- [x] `GET /api/v3/admin/taxons` — List all taxons across taxonomies
- [x] `GET /api/v3/admin/taxons/:id` — Show taxon

### Classifications (Product-Taxon assignments, nested under Taxons)
- [ ] `GET /api/v3/admin/taxons/:taxon_id/classifications` — List products in taxon
- [ ] `POST /api/v3/admin/taxons/:taxon_id/classifications` — Add product to taxon
- [ ] `PATCH /api/v3/admin/taxons/:taxon_id/classifications/:id` — Update position
- [ ] `DELETE /api/v3/admin/taxons/:taxon_id/classifications/:id` — Remove product from taxon

### Orders (⭐ high priority)
- [x] `GET /api/v3/admin/orders` — List orders (with Ransack filtering, sorting, pagination)
- [x] `GET /api/v3/admin/orders/:id` — Show order
- [x] `POST /api/v3/admin/orders` — Create draft order
- [x] `PATCH /api/v3/admin/orders/:id` — Update order
- [x] `DELETE /api/v3/admin/orders/:id` — Delete draft order
- [x] `PATCH /api/v3/admin/orders/:id/next` — Push the order to the next state
- [x] `PATCH /api/v3/admin/orders/:id/advance` — Advance the order to the furthest state
- [x] `PATCH /api/v3/admin/orders/:id/complete` — Complete the order
- [x] `PATCH /api/v3/admin/orders/:id/cancel` — Cancel order
- [x] `PATCH /api/v3/admin/orders/:id/approve` — Approve order
- [x] `PATCH /api/v3/admin/orders/:id/resume` — Resume canceled order
- [x] `POST /api/v3/admin/orders/:id/resend_confirmation` — Resend confirmation email

### Line Items (nested under Orders)
- [x] `GET /api/v3/admin/orders/:order_id/line_items` — List line items
- [x] `POST /api/v3/admin/orders/:order_id/line_items` — Add line item
- [x] `PATCH /api/v3/admin/orders/:order_id/line_items/:id` — Update line item (quantity, price)
- [x] `DELETE /api/v3/admin/orders/:order_id/line_items/:id` — Remove line item

### Shipments (nested under Orders)
- [x] `GET /api/v3/admin/orders/:order_id/shipments` — List shipments
- [x] `GET /api/v3/admin/orders/:order_id/shipments/:id` — Show shipment
- [ ] `POST /api/v3/admin/orders/:order_id/shipments` — Create shipment
- [x] `PATCH /api/v3/admin/orders/:order_id/shipments/:id` — Update shipment
- [x] `PATCH /api/v3/admin/orders/:order_id/shipments/:id/ship` — Mark shipment as shipped
- [x] `PATCH /api/v3/admin/orders/:order_id/shipments/:id/cancel` — Cancel a shipment
- [x] `PATCH /api/v3/admin/orders/:order_id/shipments/:id/resume` — Resume a canceled shipment
- [x] `PATCH /api/v3/admin/orders/:order_id/shipments/:id/split` — Split/transfer items to a new shipment

### Payments (nested under Orders)
- [x] `GET /api/v3/admin/orders/:order_id/payments` — List payments
- [x] `GET /api/v3/admin/orders/:order_id/payments/:id` — Show payment
- [x] `POST /api/v3/admin/orders/:order_id/payments` — Create payment
- [x] `PATCH /api/v3/admin/orders/:order_id/payments/:id/capture` — Capture payment
- [x] `PATCH /api/v3/admin/orders/:order_id/payments/:id/void` — Void payment

### Refunds (nested under Orders)
- [x] `GET /api/v3/admin/orders/:order_id/refunds` — List refunds
- [x] `POST /api/v3/admin/orders/:order_id/refunds` — Create refund (with payment_id in body)
- [ ] `PATCH /api/v3/admin/orders/:order_id/refunds/:id` — Update refund

### Adjustments (nested under Orders)
- [x] `GET /api/v3/admin/orders/:order_id/adjustments` — List adjustments
- [x] `POST /api/v3/admin/orders/:order_id/adjustments` — Create adjustment
- [x] `PATCH /api/v3/admin/orders/:order_id/adjustments/:id` — Update adjustment
- [x] `DELETE /api/v3/admin/orders/:order_id/adjustments/:id` — Delete adjustment

### Order User Assignment
- [ ] `PUT /api/v3/admin/orders/:order_id/user` — Assign user to order
- [ ] `DELETE /api/v3/admin/orders/:order_id/user` — Remove user from order

### Order Promotions
- [ ] `POST /api/v3/admin/orders/:order_id/promotions` — Apply promotion to order (by promotion_id or coupon_code)
- [ ] `DELETE /api/v3/admin/orders/:order_id/promotions/:id` — Remove promotion from order

### Return Authorizations
- [ ] `GET /api/v3/admin/return_authorizations` — List all return authorizations
- [ ] `GET /api/v3/admin/orders/:order_id/return_authorizations` — List return authorizations for order
- [ ] `GET /api/v3/admin/orders/:order_id/return_authorizations/:id` — Show return authorization
- [ ] `POST /api/v3/admin/orders/:order_id/return_authorizations` — Create return authorization
- [ ] `PATCH /api/v3/admin/orders/:order_id/return_authorizations/:id` — Update return authorization
- [ ] `DELETE /api/v3/admin/return_authorizations/:id` — Delete return authorization
- [ ] `PATCH /api/v3/admin/return_authorizations/:id/cancel` — Cancel return authorization

### Customer Returns
- [ ] `GET /api/v3/admin/customer_returns` — List all customer returns
- [ ] `GET /api/v3/admin/orders/:order_id/customer_returns` — List customer returns for order
- [ ] `POST /api/v3/admin/orders/:order_id/customer_returns` — Create customer return
- [ ] `PATCH /api/v3/admin/orders/:order_id/customer_returns/:id` — Update customer return

### Return Items
- [ ] `PATCH /api/v3/admin/return_items/:id` — Update return item (reception status, acceptance status)

### Reimbursements (nested under Orders)
- [ ] `GET /api/v3/admin/orders/:order_id/reimbursements` — List reimbursements
- [ ] `POST /api/v3/admin/orders/:order_id/reimbursements` — Create reimbursement
- [ ] `PATCH /api/v3/admin/orders/:order_id/reimbursements/:id` — Update reimbursement
- [ ] `DELETE /api/v3/admin/orders/:order_id/reimbursements/:id` — Delete reimbursement
- [ ] `POST /api/v3/admin/orders/:order_id/reimbursements/:id/perform` — Perform reimbursement

### Customers (Users)
- [ ] `GET /api/v3/admin/customers` — List customers
- [ ] `GET /api/v3/admin/customers/:id` — Show customer
- [ ] `POST /api/v3/admin/customers` — Create customer
- [ ] `PATCH /api/v3/admin/customers/:id` — Update customer
- [ ] `DELETE /api/v3/admin/customers/:id` — Delete customer

### Customer Addresses (nested under Customers)
- [ ] `GET /api/v3/admin/customers/:customer_id/addresses` — List addresses
- [ ] `POST /api/v3/admin/customers/:customer_id/addresses` — Create address
- [ ] `PATCH /api/v3/admin/customers/:customer_id/addresses/:id` — Update address
- [ ] `DELETE /api/v3/admin/customers/:customer_id/addresses/:id` — Delete address

### Store Credits (nested under Customers)
- [ ] `GET /api/v3/admin/customers/:customer_id/store_credits` — List store credits
- [ ] `GET /api/v3/admin/customers/:customer_id/store_credits/:id` — Show store credit
- [ ] `POST /api/v3/admin/customers/:customer_id/store_credits` — Create store credit
- [ ] `PATCH /api/v3/admin/customers/:customer_id/store_credits/:id` — Update store credit
- [ ] `DELETE /api/v3/admin/customers/:customer_id/store_credits/:id` — Delete store credit

### Gift Cards
- [ ] `GET /api/v3/admin/gift_cards` — List gift cards
- [ ] `GET /api/v3/admin/gift_cards/:id` — Show gift card
- [ ] `POST /api/v3/admin/gift_cards` — Create gift card
- [ ] `PATCH /api/v3/admin/gift_cards/:id` — Update gift card
- [ ] `DELETE /api/v3/admin/gift_cards/:id` — Delete gift card
- [ ] `POST /api/v3/admin/gift_card_batches` — Batch create gift cards

### Customer Groups
- [ ] `GET /api/v3/admin/customer_groups` — List customer groups
- [ ] `GET /api/v3/admin/customer_groups/:id` — Show customer group
- [ ] `POST /api/v3/admin/customer_groups` — Create customer group
- [ ] `PATCH /api/v3/admin/customer_groups/:id` — Update customer group
- [ ] `DELETE /api/v3/admin/customer_groups/:id` — Delete customer group

### Customer Group Members (nested under Customer Groups)
- [ ] `GET /api/v3/admin/customer_groups/:customer_group_id/members` — List members
- [ ] `POST /api/v3/admin/customer_groups/:customer_group_id/members` — Add members (bulk)
- [ ] `DELETE /api/v3/admin/customer_groups/:customer_group_id/members/:id` — Remove member
- [ ] `DELETE /api/v3/admin/customer_groups/:customer_group_id/members` — Remove members (bulk)

### Newsletter Subscribers
- [ ] `GET /api/v3/admin/newsletter_subscribers` — List subscribers
- [ ] `DELETE /api/v3/admin/newsletter_subscribers/:id` — Delete subscriber

### Promotions
- [ ] `GET /api/v3/admin/promotions` — List promotions
- [ ] `GET /api/v3/admin/promotions/:id` — Show promotion
- [ ] `POST /api/v3/admin/promotions` — Create promotion
- [ ] `PATCH /api/v3/admin/promotions/:id` — Update promotion
- [ ] `DELETE /api/v3/admin/promotions/:id` — Delete promotion
- [ ] `POST /api/v3/admin/promotions/:id/clone` — Clone promotion

### Promotion Actions (nested under Promotions)
- [ ] `GET /api/v3/admin/promotions/:promotion_id/actions` — List promotion actions
- [ ] `POST /api/v3/admin/promotions/:promotion_id/actions` — Create promotion action
- [ ] `PATCH /api/v3/admin/promotions/:promotion_id/actions/:id` — Update promotion action
- [ ] `DELETE /api/v3/admin/promotions/:promotion_id/actions/:id` — Delete promotion action

### Promotion Rules (nested under Promotions)
- [ ] `GET /api/v3/admin/promotions/:promotion_id/rules` — List promotion rules
- [ ] `POST /api/v3/admin/promotions/:promotion_id/rules` — Create promotion rule
- [ ] `PATCH /api/v3/admin/promotions/:promotion_id/rules/:id` — Update promotion rule
- [ ] `DELETE /api/v3/admin/promotions/:promotion_id/rules/:id` — Delete promotion rule

### Coupon Codes (nested under Promotions, read-only)
- [ ] `GET /api/v3/admin/promotions/:promotion_id/coupon_codes` — List coupon codes

### Stock Locations
- [ ] `GET /api/v3/admin/stock_locations` — List stock locations
- [ ] `GET /api/v3/admin/stock_locations/:id` — Show stock location
- [ ] `POST /api/v3/admin/stock_locations` — Create stock location
- [ ] `PATCH /api/v3/admin/stock_locations/:id` — Update stock location
- [ ] `DELETE /api/v3/admin/stock_locations/:id` — Delete stock location

### Stock Items
- [ ] `GET /api/v3/admin/stock_items` — List stock items (filterable by stock_location, variant)
- [ ] `PATCH /api/v3/admin/stock_items/:id` — Update stock item (count_on_hand, backorderable)
- [ ] `DELETE /api/v3/admin/stock_items/:id` — Delete stock item

### Stock Transfers
- [ ] `GET /api/v3/admin/stock_transfers` — List stock transfers
- [ ] `GET /api/v3/admin/stock_transfers/:id` — Show stock transfer
- [ ] `POST /api/v3/admin/stock_transfers` — Create stock transfer
- [ ] `DELETE /api/v3/admin/stock_transfers/:id` — Delete stock transfer

### Price Lists
- [ ] `GET /api/v3/admin/price_lists` — List price lists
- [ ] `GET /api/v3/admin/price_lists/:id` — Show price list
- [ ] `POST /api/v3/admin/price_lists` — Create price list
- [ ] `PATCH /api/v3/admin/price_lists/:id` — Update price list
- [ ] `DELETE /api/v3/admin/price_lists/:id` — Delete price list

### Price Rules (nested under Price Lists)
- [ ] `GET /api/v3/admin/price_lists/:price_list_id/price_rules` — List price rules
- [ ] `POST /api/v3/admin/price_lists/:price_list_id/price_rules` — Create price rule
- [ ] `PATCH /api/v3/admin/price_lists/:price_list_id/price_rules/:id` — Update price rule
- [ ] `DELETE /api/v3/admin/price_lists/:price_list_id/price_rules/:id` — Delete price rule

### Price List Products (nested under Price Lists)
- [ ] `GET /api/v3/admin/price_lists/:price_list_id/products` — List products in price list
- [ ] `POST /api/v3/admin/price_lists/:price_list_id/products` — Add products to price list (bulk)
- [ ] `DELETE /api/v3/admin/price_lists/:price_list_id/products` — Remove products from price list (bulk)

### Payment Methods
- [ ] `GET /api/v3/admin/payment_methods` — List payment methods
- [ ] `GET /api/v3/admin/payment_methods/:id` — Show payment method
- [ ] `POST /api/v3/admin/payment_methods` — Create payment method
- [ ] `PATCH /api/v3/admin/payment_methods/:id` — Update payment method
- [ ] `DELETE /api/v3/admin/payment_methods/:id` — Delete payment method

### Shipping Methods
- [ ] `GET /api/v3/admin/shipping_methods` — List shipping methods
- [ ] `GET /api/v3/admin/shipping_methods/:id` — Show shipping method
- [ ] `POST /api/v3/admin/shipping_methods` — Create shipping method
- [ ] `PATCH /api/v3/admin/shipping_methods/:id` — Update shipping method
- [ ] `DELETE /api/v3/admin/shipping_methods/:id` — Delete shipping method

### Shipping Categories
- [ ] `GET /api/v3/admin/shipping_categories` — List shipping categories
- [ ] `GET /api/v3/admin/shipping_categories/:id` — Show shipping category
- [ ] `POST /api/v3/admin/shipping_categories` — Create shipping category
- [ ] `PATCH /api/v3/admin/shipping_categories/:id` — Update shipping category
- [ ] `DELETE /api/v3/admin/shipping_categories/:id` — Delete shipping category

### Tax Categories
- [ ] `GET /api/v3/admin/tax_categories` — List tax categories
- [ ] `GET /api/v3/admin/tax_categories/:id` — Show tax category
- [ ] `POST /api/v3/admin/tax_categories` — Create tax category
- [ ] `PATCH /api/v3/admin/tax_categories/:id` — Update tax category
- [ ] `DELETE /api/v3/admin/tax_categories/:id` — Delete tax category

### Tax Rates
- [ ] `GET /api/v3/admin/tax_rates` — List tax rates
- [ ] `GET /api/v3/admin/tax_rates/:id` — Show tax rate
- [ ] `POST /api/v3/admin/tax_rates` — Create tax rate
- [ ] `PATCH /api/v3/admin/tax_rates/:id` — Update tax rate
- [ ] `DELETE /api/v3/admin/tax_rates/:id` — Delete tax rate

### Zones
- [ ] `GET /api/v3/admin/zones` — List zones
- [ ] `GET /api/v3/admin/zones/:id` — Show zone
- [ ] `POST /api/v3/admin/zones` — Create zone
- [ ] `PATCH /api/v3/admin/zones/:id` — Update zone
- [ ] `DELETE /api/v3/admin/zones/:id` — Delete zone

### Markets
- [ ] `GET /api/v3/admin/markets` — List markets
- [ ] `GET /api/v3/admin/markets/:id` — Show market
- [ ] `POST /api/v3/admin/markets` — Create market
- [ ] `PATCH /api/v3/admin/markets/:id` — Update market
- [ ] `DELETE /api/v3/admin/markets/:id` — Delete market

### Countries
- [ ] `GET /api/v3/admin/countries` — List countries
- [ ] `GET /api/v3/admin/countries/:id` — Show country

### Store Settings
- [ ] `GET /api/v3/admin/store` — Get current store settings
- [ ] `PATCH /api/v3/admin/store` — Update store settings

### Policies
- [ ] `GET /api/v3/admin/policies` — List policies
- [ ] `GET /api/v3/admin/policies/:id` — Show policy
- [ ] `POST /api/v3/admin/policies` — Create policy
- [ ] `PATCH /api/v3/admin/policies/:id` — Update policy
- [ ] `DELETE /api/v3/admin/policies/:id` — Delete policy

### Admin Users
- [ ] `GET /api/v3/admin/admin_users` — List admin users
- [ ] `GET /api/v3/admin/admin_users/:id` — Show admin user
- [ ] `POST /api/v3/admin/admin_users` — Create admin user
- [ ] `PATCH /api/v3/admin/admin_users/:id` — Update admin user
- [ ] `DELETE /api/v3/admin/admin_users/:id` — Delete admin user

### Roles
- [ ] `GET /api/v3/admin/roles` — List roles
- [ ] `GET /api/v3/admin/roles/:id` — Show role
- [ ] `POST /api/v3/admin/roles` — Create role
- [ ] `PATCH /api/v3/admin/roles/:id` — Update role
- [ ] `DELETE /api/v3/admin/roles/:id` — Delete role

### Invitations
- [ ] `GET /api/v3/admin/invitations` — List invitations
- [ ] `POST /api/v3/admin/invitations` — Create invitation
- [ ] `DELETE /api/v3/admin/invitations/:id` — Delete invitation
- [ ] `PATCH /api/v3/admin/invitations/:id/resend` — Resend invitation

### Metafield Definitions
- [ ] `GET /api/v3/admin/metafield_definitions` — List metafield definitions
- [ ] `GET /api/v3/admin/metafield_definitions/:id` — Show metafield definition
- [ ] `POST /api/v3/admin/metafield_definitions` — Create metafield definition
- [ ] `PATCH /api/v3/admin/metafield_definitions/:id` — Update metafield definition
- [ ] `DELETE /api/v3/admin/metafield_definitions/:id` — Delete metafield definition

### Metafields (polymorphic, nested under any resource)
- [ ] `GET /api/v3/admin/:resource_type/:resource_id/metafields` — List metafields for resource
- [ ] `POST /api/v3/admin/:resource_type/:resource_id/metafields` — Create metafield
- [ ] `PATCH /api/v3/admin/:resource_type/:resource_id/metafields/:id` — Update metafield
- [ ] `DELETE /api/v3/admin/:resource_type/:resource_id/metafields/:id` — Delete metafield

### Translations (polymorphic, nested under any translatable resource)
- [ ] `GET /api/v3/admin/:resource_type/:resource_id/translations` — List translations for resource
- [ ] `PATCH /api/v3/admin/:resource_type/:resource_id/translations` — Update translations for resource

### Tags
- [ ] `GET /api/v3/admin/tags` — List tags
- [ ] `POST /api/v3/admin/tags` — Create tag
- [ ] `DELETE /api/v3/admin/tags/:id` — Delete tag

### Refund Reasons
- [ ] `GET /api/v3/admin/refund_reasons` — List refund reasons
- [ ] `GET /api/v3/admin/refund_reasons/:id` — Show refund reason
- [ ] `POST /api/v3/admin/refund_reasons` — Create refund reason
- [ ] `PATCH /api/v3/admin/refund_reasons/:id` — Update refund reason
- [ ] `DELETE /api/v3/admin/refund_reasons/:id` — Delete refund reason

### Return Authorization Reasons
- [ ] `GET /api/v3/admin/return_authorization_reasons` — List reasons
- [ ] `GET /api/v3/admin/return_authorization_reasons/:id` — Show reason
- [ ] `POST /api/v3/admin/return_authorization_reasons` — Create reason
- [ ] `PATCH /api/v3/admin/return_authorization_reasons/:id` — Update reason
- [ ] `DELETE /api/v3/admin/return_authorization_reasons/:id` — Delete reason

### Store Credit Categories
- [ ] `GET /api/v3/admin/store_credit_categories` — List categories
- [ ] `GET /api/v3/admin/store_credit_categories/:id` — Show category
- [ ] `POST /api/v3/admin/store_credit_categories` — Create category
- [ ] `PATCH /api/v3/admin/store_credit_categories/:id` — Update category
- [ ] `DELETE /api/v3/admin/store_credit_categories/:id` — Delete category

### Reimbursement Types
- [ ] `GET /api/v3/admin/reimbursement_types` — List types
- [ ] `GET /api/v3/admin/reimbursement_types/:id` — Show type
- [ ] `POST /api/v3/admin/reimbursement_types` — Create type
- [ ] `PATCH /api/v3/admin/reimbursement_types/:id` — Update type
- [ ] `DELETE /api/v3/admin/reimbursement_types/:id` — Delete type

### Webhook Endpoints
- [ ] `GET /api/v3/admin/webhook_endpoints` — List webhook endpoints
- [ ] `GET /api/v3/admin/webhook_endpoints/:id` — Show webhook endpoint
- [ ] `POST /api/v3/admin/webhook_endpoints` — Create webhook endpoint
- [ ] `PATCH /api/v3/admin/webhook_endpoints/:id` — Update webhook endpoint
- [ ] `DELETE /api/v3/admin/webhook_endpoints/:id` — Delete webhook endpoint

### Webhook Deliveries (nested under Webhook Endpoints, read-only)
- [ ] `GET /api/v3/admin/webhook_endpoints/:webhook_endpoint_id/deliveries` — List deliveries
- [ ] `GET /api/v3/admin/webhook_endpoints/:webhook_endpoint_id/deliveries/:id` — Show delivery

### API Keys
- [ ] `GET /api/v3/admin/api_keys` — List API keys
- [ ] `POST /api/v3/admin/api_keys` — Create API key
- [ ] `PATCH /api/v3/admin/api_keys/:id` — Update API key
- [ ] `DELETE /api/v3/admin/api_keys/:id` — Delete API key
- [ ] `PATCH /api/v3/admin/api_keys/:id/revoke` — Revoke API key

### Integrations
- [ ] `GET /api/v3/admin/integrations` — List integrations
- [ ] `GET /api/v3/admin/integrations/:id` — Show integration
- [ ] `POST /api/v3/admin/integrations` — Create integration
- [ ] `PATCH /api/v3/admin/integrations/:id` — Update integration
- [ ] `DELETE /api/v3/admin/integrations/:id` — Delete integration

### Reports
- [ ] `GET /api/v3/admin/reports` — List reports
- [ ] `GET /api/v3/admin/reports/:id` — Show report
- [ ] `POST /api/v3/admin/reports` — Create/generate report

### Exports
- [ ] `GET /api/v3/admin/exports` — List exports
- [ ] `GET /api/v3/admin/exports/:id` — Show export (with download URL)
- [ ] `POST /api/v3/admin/exports` — Create export

### Imports
- [ ] `GET /api/v3/admin/imports` — List imports
- [ ] `GET /api/v3/admin/imports/:id` — Show import (with status, row counts)
- [ ] `POST /api/v3/admin/imports` — Create import (multipart/form-data)
- [ ] `PATCH /api/v3/admin/imports/:id/complete_mapping` — Complete field mapping and start import

### Dashboard
- [ ] `GET /api/v3/admin/dashboard/analytics` — Get dashboard analytics data

**Total: 296 endpoints**

After implementing each endpoint please mark it as done on the list above.
