---
title: Variants
description: Use the Spree Commerce storefront API to access Variant data.
---

## Index

To return a paginated list of all variants within the store, make this request:

```text
GET /api/v1/variants
```

You can limit this to showing the variants for a particular product by passing through a product's slug:

```text
GET /api/v1/products/ruby-on-rails-tote/variants
```

or

```text
GET /api/v1/variants?product_id=ruby-on-rails-tote
```

### Parameters

<params params='[
  {
    "name": "show_deleted",
    "description": "**boolean** - `true` to show deleted variants, `false` to hide them. Default: `false`. **Only available to users with an admin role.**"
  }, {
    "name": "page",
    "description": "The page number of variants to display."
  }, {
    "name": "per_page",
    "description": "The number of variants to return per page"
  }
]'></params>

### Response

<status code="200"></status>
<json sample="variants_big"></json>

## Search

To search for a particular variant, make a request like this:

```text
GET /api/v1/variants?q[sku_cont]=foo
```

You can limit this to showing the variants for a particular product by passing through a product id:

```text
GET /api/v1/products/ruby-on-rails-tote/variants?q[sku_cont]=foo
```

or

```text
GET /api/v1/variants?product_id=ruby-on-rails-tote&q[sku_cont]=foo
```


The searching API is provided through the Ransack gem which Spree depends on. The `sku_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<status code="200"></status>
<json sample="variants_big" merge='{"count": 1, "total_count": 1, "current_page": 1,  "pages": 1}'></json>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

```text
GET /api/v1/variants?q[s]=price%20asc
```

It is also possible to sort results using an associated object's field.

```text
GET /api/v1/variants?q[s]=product_name%20asc
```

## Show

To view the details for a single variant, make a request using that variant\'s id, along with the product's permalink as its `product_id`:

```text
GET /api/v1/products/ruby-on-rails-tote/variants/1
```

Or:

```text
GET /api/v1/variants/1?product_id=ruby-on-rails-tote
```

### Successful Response

<status code="200"></status>
<json sample="variant"></json>

### Not Found Response

<alert type="not_found"></alert>

## New

You can learn about the potential attributes (required and non-required) for a variant by making this request:

```text
GET /api/v1/products/ruby-on-rails-tote/variants/new
```

### Response

<status code="200"></status>
```json
{
  "attributes": [
    "id", "name", "sku", "price", "weight", "height",
    "width", "depth", "is_master", "slug", "description", "track_inventory"
  ],
  "required_attributes": []
}
```

## Create

<alert type="admin_only" kind="danger"></alert>

To create a new variant for a product, make this request with the necessary parameters:

```text
POST /api/v1/products/ruby-on-rails-tote/variants
```

For instance, a request to create a new variant with a SKU of 12345 and a price of 19.99 would look like this::

```text
POST /api/v1/products/ruby-on-rails-tote/variants/?variant[sku]=12345&variant[price]=19.99&variant[option_value_ids][]=1
```

### Successful response

<status code="201"></status>
<json sample="variant_big" merge='{"sku": "12345", "price": 19.99}'></json>

### Failed response

<status code="422"></status>
```json
{
  "error": "Invalid resource. Please fix errors and try again.",
  "errors": {}
}
```

## Update

<alert type="admin_only" kind="danger"></alert>

To update a variant\'s details, make this request with the necessary parameters:

```text
PUT /api/v1/products/ruby-on-rails-tote/variants/2
```

For instance, to update a variant\'s SKU, send it through like this:

```text
PUT /api/v1/products/ruby-on-rails-tote/variants/2?variant[sku]=12345
```

### Successful response

<status code="201"></status>
<json sample="variant_big" merge='{"sku": "12345"}'></json>

### Failed response

<status code="422"></status>
```json
{
  "error": "Invalid resource. Please fix errors and try again.",
  "errors": {}
}
```

## Delete

<alert type="admin_only" kind="danger"></alert>

To delete a variant, make this request:

```text
DELETE /api/v1/products/ruby-on-rails-tote/variants/2
```

This request, much like a typical variant \"deletion\" through the admin interface, will not actually remove the record from the database. It simply sets the `deleted_at` field to the current time on the variant.

<status code="204"></status>
