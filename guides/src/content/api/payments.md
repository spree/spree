---
title: Payments
description: Use the Spree Commerce storefront API to access Payment data.
---

# Payments API

## Index

To see details about an order's payments, make this request:

    GET /api/v1/orders/R1234567/payments

Payments are paginated and can be iterated through by passing along a `page` parameter:

    GET /api/v1/orders/R1234567/payments?page=2

### Parameters

page
: The page number of payment to display.

per_page
: The number of payments to return per page

### Response

<%= headers 200 %>
<%= json(:payment) do |h|
{ payments: [h],
  count: 2,
  current_page: 1,
  pages: 2 }
end %>

## Search

To search for a particular payment, make a request like this:

    GET /api/v1/orders/R1234567/payments?q[response_code_cont]=123

The searching API is provided through the Ransack gem which Spree depends on. The `response_code_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<%= headers 200 %>
<%= json(:payment) do |h|
{ payments: [h],
  count: 2,
  current_page: 1,
  pages: 2 }
end %>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

    GET /api/v1/payments?q[s]=state%20desc

## New

In order to create a new payment, you will need to know about the available payment methods and attributes. To find these out, make this request:

    GET /api/v1/orders/R1234567/payments/new

### Response

<%= headers 200 %>
<%= json \
  attributes:
  ["id", "source_type", "source_id", "amount",
   "display_amount", "payment_method_id", "state", "avs_response",
   "created_at", "updated_at", "number"],
  payment_methods: [Spree::Resources::PAYMENT_METHOD] %>

## Create

To create a new payment, make a request like this:

    POST /api/v1/orders/R1234567/payments?payment[payment_method_id]=1&payment[amount]=10

### Response

<%= headers 201 %>
<%= json(:payment) %>

## Show

To get information for a particular payment, make a request like this:

    GET /api/v1/orders/R1234567/payments/1

### Response

<%= headers 200 %>
<%= json(:payment) %>

## Authorize

To authorize a payment, make a request like this:

    PUT /api/v1/orders/R1234567/payments/1/authorize

### Response

<%= headers 200 %>
<%= json :payment %>

### Failed Response

<%= headers 422 %>
<%= json error: "There was a problem with the payment gateway: [text]" %>

## Capture

<%= warning "Capturing a payment is typically done shortly after authorizing the payment. If you are auto-capturing payments, you may be able to use the purchase endpoint instead." %>

To capture a payment, make a request like this:

    PUT /api/v1/orders/R1234567/payments/1/capture

### Response

<%= headers 200 %>
<%= json :payment %>

### Failed Response

<%= headers 422 %>
<%= json error: "There was a problem with the payment gateway: [text]" %>

## Purchase

<%= warning "Purchasing a payment is typically done only if you are not authorizing payments before-hand. If you are authorizing payments, then use the authorize and capture endpoints instead." %>

To make a purchase with a payment, make a request like this:

    PUT /api/v1/orders/R1234567/payments/1/purchase

### Response

<%= headers 200 %>
<%= json :payment %>

### Failed Response

<%= headers 422 %>
<%= json error: "There was a problem with the payment gateway: [text]" %>

## Void

To void a payment, make a request like this:

    PUT /api/v1/orders/R1234567/payments/1/void

### Response

<%= headers 200 %>
<%= json :payment %>

### Failed Response

<%= headers 422 %>
<%= json error: "There was a problem with the payment gateway: [text]" %>

## Credit

To credit a payment, make a request like this:

    PUT /api/v1/orders/R1234567/payments/1/credit?amount=10

If the payment is over the payment's credit allowed limit, a "Credit Over Limit" response will be returned.

### Response

<%= headers 200 %>
<%= json :payment %>

### Failed Response

<%= headers 422 %>
<%= json error: "There was a problem with the payment gateway: [text]" %>

### Credit Over Limit Response

<%= headers 422 %>
<%= json error: "This payment can only be credited up to [amount]. Please specify an amount less than or equal to this number." %>
