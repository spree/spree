---
title: Stock Items
description: Use the Spree Commerce storefront API to access StockItem data.
---

## Index

<alert type="admin_only" kind="danger"></alert>

To return a paginated list of all stock items for a stock location, make this request, passing the stock location id you wish to see stock items for:

```text
GET /api/v1/stock_locations/1/stock_items
```

### Parameters

<params params='[
  {
    "name": "page",
    "description": "The page number of stock items to display."
  }, {
    "name": "per_page",
    "description": "The number of stock items to return per page"
  }
]'></params>

### Response

<status code="200"></status>
<json sample="stock_items"></json>

## Search

<alert type="admin_only" kind="danger"></alert>

To search for a particular stock item, make a request like this:

```text
GET /api/v1/stock_locations/1/stock_items?q[variant_id_eq]=10
```

The searching API is provided through the Ransack gem which Spree depends on. The `variant_id_eq` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<status code="200"></status>
<json sample="stock_items"></json>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

```text
GET /api/v1/stock_locations/1/stock_items?q[s]=variant_id%20asc
```

## Show

<alert type="admin_only" kind="danger"></alert>

To view the details for a single stock item, make a request using that stock item's id, along with its `stock_location_id`:

```text
GET /api/v1/stock_locations/1/stock_items/2
```

### Successful Response

<status code="200"></status>
<json sample="stock_item"></json>

### Not Found Response

<alert type="not_found"></alert>

## Create

<alert type="admin_only" kind="danger"></alert>

To create a new stock item for a stock location, make this request with the necessary parameters:

```text
POST /api/v1/stock_locations/1/stock_items
```

For instance, a request to create a new stock item with a count_on_hand of 10 and a variant_id of 1 would look like this::

```json
{
  "stock_item": {
    "count_on_hand": 10,
    "variant_id": "1",
    "backorderable": true
  }
}
```

### Successful response

<status code="201"></status>
<json sample="stock_item"></json>

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

Note that using this endpoint, count_on_hand <strong>IS APPENDED</strong> to its current value.

Sending a request with a negative count_on_hand <strong>WILL SUBSTRACT</strong> the current value.

To force a value for count_on_hand, include force: true in your request, this will replace the current
value as it's stored in the database.

To update a stock item's details, make this request with the necessary parameters.

```text
PUT /api/v1/stock_locations/1/stock_items/2
```

For instance, to update a stock item's count_on_hand, send it through like this:

```json
{
  "stock_item": {
    "count_on_hand": 30
  }
}
```

Or alternatively with the force attribute to replace the current count_on_hand with a new value:

```json
{
  "stock_item": {
    "count_on_hand": 30,
    "force": true,
  }
}
```

### Successful response

<status code="201"></status>
<json sample="stock_item" merge='{"count_on_hand": 30}'></json>

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

To delete a stock item, make this request:

```text
DELETE /api/v1/stock_locations/1/stock_items/2
```

### Response

<status code="204"></status>
