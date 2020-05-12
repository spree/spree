---
title: Customer Returns
description: Use the Spree Commerce storefront API to access Customer Returns data.
---

## Index

Retrieve a list of customer returns by making this request:

```text
GET /api/v1/customer_returns
```

Customer returns are paginated and can be iterated through by passing along a `page` parameter:

```text
GET /api/v1/customer_returns?page=2
```

### Parameters

<params params='[
  {
    "name": "page",
    "description": "The page number of customer return to display."
  }, {
    "name": "per_page",
    "description": "The number of customer returns to return per page"
  }
]'></params>

### Response

<status code="200"></status>
<json sample="customer_returns"></json>

## Search

To search for a particular customer return, make a request like this:

```text
GET /api/v1/customer_returns?q[number_cont]=CR972477438
```

The searching API is provided through the Ransack gem which Spree depends on. The `number_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<status code="200"></status>
<json sample="customer_returns"></json>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

```text
GET /api/v1/customer_returns?q[s]=updated_at%20desc
```
