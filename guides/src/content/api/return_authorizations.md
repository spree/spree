---
title: Return Authorizations
description: Use the Spree Commerce storefront API to access ReturnAuthorization data.
---

## Index

To list all return authorizations for an order, make a request like this:

    GET /api/v1/orders/R1234567/return_authorizations

Return authorizations are paginated and can be iterated through by passing along a `page` parameter:

    GET /api/v1/orders/R1234567/return_authorizations?page=2

### Parameters

<params params='[
  {
    "name": "page",
    "description": "The page number of return authorization to display."
  }, {
    "name": "per_page",
    "description": "The number of return authorizations to return per page"
  }
]'></params>


### Response

<status code="200"></status>
<json sample="return_authorizations"></json>

## Search

To search for a particular return authorization, make a request like this:

    GET /api/v1/orders/R1234567/return_authorizations?q[memo_cont]=damage

The searching API is provided through the Ransack gem which Spree depends on. The `memo_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

    GET /api/v1/orders/R1234567/return_authorizations?q[s]=amount%20asc

### Response

<status code="200"></status>
<json sample="return_authorizations" merge='{"count": 1}'></json>

## Show

To get information for a single return authorization, make a request like this:

     GET /api/v1/orders/R1234567/return_authorizations/1

### Response

<status code="200"></status>
<json sample="return_authorization"></json>

## Create

<alert type="admin_only" kind="danger"></alert>

To create a return authorization, make a request like this:

     POST /api/v1/orders/R1234567/return_authorizations

For instance, if you want to create a return authorization with a number, make
above request with following parameters:

```json
{
  "order_id": "R1234567",
  "return_authorization": {
    "stock_location_id": 1,
    "return_authorization_reason_id": 2
  }
}
```

### Response

<status code="201"></status>
<json sample="return_authorization"></json>

## Update

<alert type="admin_only" kind="danger"></alert>

To update a return authorization, make a request like this:

     PUT /api/v1/orders/R1234567/return_authorizations/1

For instance, to update a return authorization's number, make this request:

     PUT /api/v1/orders/R1234567/return_authorizations/1?return_authorization[memo]=Broken

### Response

<status code="200"></status>
<json sample="return_authorization" merge='{"memo": "Broken"}'></json>

## Delete

<alert type="admin_only" kind="danger"></alert>

To delete a return authorization, make a request like this:

    DELETE /api/v1/orders/R1234567/return_authorizations/1

### Response

<status code="204"></status>
