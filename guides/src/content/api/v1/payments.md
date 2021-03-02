---
title: Payments
description: Use the Spree Commerce storefront API to access Payment data.
---

## Index

To see details about an order's payments, make this request:

    GET /api/v1/orders/R1234567/payments

Payments are paginated and can be iterated through by passing along a `page` parameter:

    GET /api/v1/orders/R1234567/payments?page=2

### Parameters

<params params='[
  {
    "name": "page",
    "description": "The page number of payments to display."
  }, {
    "name": "per_page",
    "description": "The number of payments to return per page"
  }
]'></params>

### Response

<status code="200"></status>
<json sample="payments"></json>

## Search

To search for a particular payment, make a request like this:

    GET /api/v1/orders/R1234567/payments?q[response_code_cont]=123

The searching API is provided through the Ransack gem which Spree depends on. The `response_code_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<status code="200"></status>
<json sample="payments"></json>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

    GET /api/v1/payments?q[s]=state%20desc

## New

In order to create a new payment, you will need to know about the available payment methods and attributes. To find these out, make this request:

    GET /api/v1/orders/R1234567/payments/new

### Response

<status code="200"></status>
```json
{
  "attributes": ["id", "source_type", "source_id", "amount",
   "display_amount", "payment_method_id", "state", "avs_response",
   "created_at", "updated_at", "number"],
  "payment_methods": [Spree::Resources::PAYMENT_METHOD]
}
```

## Create

To create a new payment, make a request like this:

    POST /api/v1/orders/R1234567/payments?payment[payment_method_id]=1&payment[amount]=10

### Response

<status code="201"></status>
<json sample="payment"></json>

## Show

To get information for a particular payment, make a request like this:

    GET /api/v1/orders/R1234567/payments/1

### Response

<status code="200"></status>
<json sample="payment"></json>

## Authorize

To authorize a payment, make a request like this:

    PUT /api/v1/orders/R1234567/payments/1/authorize

### Response

<status code="200"></status>
<json sample="payment"></json>

### Failed Response

<status code="422"></status>
```json
{
  "error": "There was a problem with the payment gateway: [text]"
}
```

## Capture

<alert kind="warning">
  Capturing a payment is typically done shortly after authorizing the payment. If you are auto-capturing payments, you may be able to use the purchase endpoint instead.
</alert>

To capture a payment, make a request like this:

    PUT /api/v1/orders/R1234567/payments/1/capture

### Response

<status code="200"></status>
<json sample="payment"></json>

### Failed Response

<status code="422"></status>
```json
{
  "error": "There was a problem with the payment gateway: [text]"
}
```

## Purchase

<alert kind="warning">
  Purchasing a payment is typically done only if you are not authorizing payments before-hand. If you are authorizing payments, then use the authorize and capture endpoints instead.
</alert>

To make a purchase with a payment, make a request like this:

    PUT /api/v1/orders/R1234567/payments/1/purchase

### Response

<status code="200"></status>
<json sample="payment"></json>

### Failed Response

<status code="422"></status>
```json
{
  "error": "There was a problem with the payment gateway: [text]"
}
```

## Void

To void a payment, make a request like this:

    PUT /api/v1/orders/R1234567/payments/1/void

### Response

<status code="200"></status>
<json sample="payment"></json>

### Failed Response

<status code="422"></status>
```json
{
  "error": "There was a problem with the payment gateway: [text]"
}
```

## Credit

To credit a payment, make a request like this:

    PUT /api/v1/orders/R1234567/payments/1/credit?amount=10

If the payment is over the payment's credit allowed limit, a "Credit Over Limit" response will be returned.

### Response

<status code="200"></status>
<json sample="payment"></json>

### Failed Response

<status code="422"></status>
```json
{
  "error": "There was a problem with the payment gateway: [text]"
}
```

### Credit Over Limit Response

<status code="422"></status>
```json
{
  "error": "This payment can only be credited up to [amount]. Please specify an amount less than or equal to this number."
}
```
