---
title: Products
description: Use the Spree Commerce storefront API to access Product data.
---

## Index

List products visible to the authenticated user. If the user is not an admin, they will only be able to see products which have an `available_on` date in the past. If the user is an admin, they are able to see all products.

```text
GET /api/v1/products
```

Products are paginated and can be iterated through by passing along a `page` parameter:

```text
GET /api/v1/products?page=2
```

### Parameters

<params params='[
  {
    "name": "show_deleted",
    "description": "**boolean** - `true` to show deleted products, `false` to hide them. Default: `false`. **Only available to users with an admin role.**"
  }, {
    "name": "show_discontinued",
    "description": "**boolean** - `true` to show discontinued products, `false` to hide them. Default: `false`. **Only available to users with an admin role.**"
  }, {
    "name": "ids",
    "description": "A comma-separated list of products ids. Specifying this parameter will display the respective products."
  }, {
    "name": "page",
    "description": "The page number of product properties to display."
  }, {
    "name": "per_page",
    "description": "The number of product properties to return per page"
  }
]'></params>

### Response

<status code="200"></status>
<json sample="products"></json>

## Search

To search for a particular product, make a request like this:

```text
GET /api/v1/products?q[name_cont]=Spree
```

The searching API is provided through the Ransack gem which Spree depends on. The `name_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<status code="200"></status>
<json sample="products"></json>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

```text
GET /api/v1/products?q[s]=sku%20asc
```

It is also possible to sort results using an associated object's field.

```text
GET /api/v1/products?q[s]=shipping_category_name%20asc
```

## Show

To view the details for a single product, make a request using that product\'s permalink:

```text
GET /api/v1/products/a-product
```

You may also query by the product\'s id attribute:

```text
GET /api/v1/products/1
```

Note that the API will attempt a permalink lookup before an ID lookup.

### Successful Response

<status code="200"></status>
<json sample="product"></json>

### Not Found Response

<alert type="not_found"></alert>

## New

You can learn about the potential attributes (required and non-required) for a product by making this request:

```text
GET /api/v1/products/new
```

### Response

<status code="200"></status>
```json
{
  "attributes": [
    "id", "name", "description", "price", "display_price", "available_on",
    "slug", "meta_description", "meta_keywords", "shipping_category_id",
    "taxon_ids", "total_on_hand"
  ],
  "required_attributes": ["name", "shipping_category", "price"]
}
```

## Create

<alert type="admin_only" kind="danger"></alert>

To create a new product through the API, make this request with the necessary parameters:

```text
POST /api/v1/products
```

For instance, a request to create a new product called \"Headphones\" with a price of $100 would look like this:

```text
POST /api/v1/products?product[name]=Headphones&product[price]=100&product[shipping_category_id]=1
```

### Successful response

<status code="201"></status>

### Failed response

<status code="422"></status>
```json
{
  "error": "Invalid resource. Please fix errors and try again.",
  "errors": {
    "name": ["can't be blank"],
    "price": ["can't be blank"],
    "shipping_category_id": ["can't be blank"]
  }
}
```

## Update

<alert type="admin_only" kind="danger"></alert>

To update a product\'s details, make this request with the necessary parameters:

```text
PUT /api/v1/products/a-product
```

For instance, to update a product\'s name, send it through like this:

```text
PUT /api/v1/products/a-product?product[name]=Headphones
```

### Successful response

<status code="201"></status>

### Failed response

<status code="422"></status>
```json
{
  "error": "Invalid resource. Please fix errors and try again.",
  "errors": {
    "name":: ["can't be blank"],
    "price": ["can't be blank"],
    "shipping_category_id": ["can't be blank"]
  }
}
```

## Delete

<alert type="admin_only" kind="danger"></alert>

To delete a product, make this request:

```text
DELETE /api/v1/products/a-product
```

This request, much like a typical product \"deletion\" through the admin interface, will not actually remove the record from the database. It simply sets the `deleted_at` field to the current time on the product, as well as all of that product\'s variants.

<status code="204"></status>
