---
title: Orders
description: Use the Spree Commerce storefront API to access Order data.
---

## Index

<%= admin_only %>

Retrieve a list of orders by making this request:

```text
GET /api/v1/orders```

Orders are paginated and can be iterated through by passing along a `page` parameter:

```text
GET /api/v1/orders?page=2```

### Parameters

page
: The page number of order to display.

per_page
: The number of orders to return per page

### Response

<%= headers 200 %>
<%= json(:order) do |h|
  { orders: [h],
    count: 25,
    current_page: 1,
    pages: 5 }
end %>

## Search

<%= admin_only %>

To search for a particular order, make a request like this:

```text
GET /api/v1/orders?q[email_cont]=bob```

The searching API is provided through the Ransack gem which Spree depends on. The `email_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<%= headers 200 %>
<%= json(:order) do |h|
  { orders: [h],
    count: 25,
    current_page: 1,
    pages: 5 }
end %>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

```text
GET /api/v1/orders?q[s]=number%20desc```

It is also possible to sort results using an associated object's field.

```text
GET /api/v1/orders?q[s]=user_name%20asc```

## Show

To view the details for a single order, make a request using that order\'s number:

```text
GET /api/v1/orders/R123456789```

Orders through the API will only be visible to admins and the users who own
them. If a user attempts to access an order that does not belong to them, they
will be met with an authorization error.

Users may pass in the order's token in order to be authorized to view an order:

```text
GET /api/v1/orders/R123456789?order_token=abcdef123456
```

The `order_token` parameter will work for authorizing any action for an order within Spree's API.

### Successful Response

<%= headers 200 %>
<%= json :order_show %>

### Not Found Response

<%= not_found %>

### Authorization Failure

<%= authorization_failure %>

## Show (delivery)

When an order is in the "delivery" state, additional shipments information will be returned in the API:

<%= json(:shipment) do |h|
 { shipments: [h] }
end %>

## Create

To create a new order through the API, make this request:

```text
POST /api/v1/orders```

If you wish to create an order with a line item matching to a variant whose ID is \"1\" and quantity is 5, make this request:

```text
POST /api/v1/orders

{
  "order": {
    "line_items": [
      { "variant_id": 1, "quantity": 5 }
    ]
  }
}
```

### Successful response

<%= headers 201 %>
<%= json :order_show do |h|
  h["line_items"][0]["quantity"] = 5
  h
end %>

### Failed response

<%= headers 422 %>
<%= json \
  error: "Invalid resource. Please fix errors and try again.",
  errors: {
    name: ["can't be blank"],
    price: ["can't be blank"]
  }
%>

## Update Address

To add address information to an order, please see the [checkout transitions](checkouts#checkout-transitions) section of the Checkouts guide.

## Empty

To empty an order\'s cart, make this request:

```text
PUT /api/v1/orders/R1234567/empty```

All line items will be removed from the cart and the order\'s information will
be cleared. Inventory that was previously depleted by this order will be
repleted.
