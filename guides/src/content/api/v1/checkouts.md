---
title: Checkouts
description: Use the Spree Commerce storefront API to access Checkout data.
---

## Introduction

The checkout API functionality can be used to advance an existing order's state.
Sending a `PUT` request to `/api/v1/checkouts/:number` will advance an order's
state or, failing that, report any errors.

The following sections will walk through creating a new order and advancing an order from its `cart` state to its `complete` state.

## Creating a blank order

To create a new, empty order, make this request:

```
POST /api/v1/orders.json
```

### Response

<status code="201"></status>
<json sample="new_order_show"></json>

Any time you update the order or move a checkout step you'll get
a response similar as above along with the new associated objects. e.g. addresses,
payments, shipments.

## Add line items to an order

Pass line item attributes like this:

```json
{
  "line_item": {
    "variant_id": 1,
    "quantity": 5
  }
}
```

to this api endpoint:

```
POST /api/v1/orders/:number/line_items.json
```

<status code="201"></status>
<json sample="line_item" merge='{"quantity": 5, "display_total": "$79.95", "total": 79.95}'></json>

## Updating an order

To update an order you must be authenticated as the order's user, and perform a request like this:

```
PUT /api/v1/orders/:number.json
```

If you know the order's token, then you can also update the order:

```
PUT /api/v1/orders/:number.json?order_token=abcdef123456
```

Requests performed as a non-admin or non-authorized user will be met with a 401 response from this action.

## Address

To transition an order to its next step, make a request like this:

```
PUT /api/v1/checkouts/:number/next.json
```

If the request is successful you'll get a 200 response using the same order
template shown when creating the order with the state updated. See example of
failed response below.

### Failed Response

<status code="422"></status>
<json sample="order_failed_transition"></json>

## Delivery

To advance to the next state, `delivery`, the order will first need both a shipping and billing address.

In order to update the addresses, make this request with the necessary parameters:

```
PUT /api/v1/checkouts/:number.json
```

As an example, here are the required address attributes and how they should be formatted:

```json
{
  "order": {
    "bill_address_attributes": {
      "firstname": "John",
      "lastname": "Doe",
      "address1": "233 36th Ave Ne",
      "city": "St Petersburg",
      "phone": "3014445002",
      "zipcode": "33704-1535",
      "state_id": 3534,
      "country_id": 232
    },
    "ship_address_attributes": {
      "firstname": "John",
      "lastname": "Doe",
      "address1": "233 36th Ave Ne",
      "city": "St Petersburg",
      "phone": "3014445002",
      "zipcode": "33704-1535",
      "state_id": 3534,
      "country_id": 232
    }
  }
}
```

### Response

Once valid address information has been submitted, the shipments and shipping rates
available for this order will be returned inside a `shipments` key inside the order,
as seen below:

<status code="200"></status>
```json
{
  ...
  "shipments": [
    {
      "id": 1,
      "tracking": null,
      "number": "H71216494427",
      "cost": "5.0",
      "shipped_at": null,
      "state": "pending",
      "shipping_rates": [
        {
          "id": 1,
          "name": "UPS Ground (USD)",
          "cost": "5.0",
          "selected": true,
          "shipping_method_id": 1,
          "shipping_method_code": null,
          "display_cost": "$5.00"
        },
        {
          "id": 2,
          "name": "UPS Two Day (USD)",
          "cost": "10.0",
          "selected": false,
          "shipping_method_id": 2,
          "shipping_method_code": null,
          "display_cost": "$10.00"
        },
        {
          "id": 3,
          "name": "UPS One Day (USD)",
          "cost": "15.0",
          "selected": false,
          "shipping_method_id": 3,
          "shipping_method_code": null,
          "display_cost": "$15.00"
        }
      ],
      "selected_shipping_rate": {
        "id": 1,
        "name": "UPS Ground (USD)",
        "cost": "5.0",
        "selected": true,
        "shipping_method_id": 1,
        "shipping_method_code": null,
        "display_cost": "$5.00"
      },
      "shipping_methods": [
        {
          "id": 1,
          "code": null,
          "name": "UPS Ground (USD)",
          "zones": [
            {
              "id": 2,
              "name": "North America",
              "description": "USA + Canada"
            }
          ],
          "shipping_categories": [
            {
              "id": 1,
              "name": "Default"
            }
          ]
        },
        {
          "id": 2,
          "code": null,
          "name": "UPS Two Day (USD)",
          "zones": [
            {
              "id": 2,
              "name": "North America",
              "description": "USA + Canada"
            }
          ],
          "shipping_categories": [
            {
              "id": 1,
              "name": "Default"
            }
          ]
        },
        {
          "id": 3,
          "code": null,
          "name": "UPS One Day (USD)",
          "zones": [
            {
              "id": 2,
              "name": "North America",
              "description": "USA + Canada"
            }
          ],
          "shipping_categories": [
            {
              "id": 1,
              "name": "Default"
            }
          ]
        }
      ],
      "manifest": [
        {
          "variant_id": 1,
          "quantity": 5,
          "states": {
            "on_hand": 5
          }
        }
      ],
      "adjustments": [],
      "order_id": "R608623713",
      "stock_location_name": "default"
    }
  ],
  ...
```

## Payment

To advance to the next state, `payment`, you will need to select a shipping rate
for each shipment for the order. These were returned when transitioning to the
`delivery` step. If you want to see them again, make the following request:

```
GET /api/v1/orders/:number.json
```

Spree will select a shipping rate by default so you can advance to the `payment`
state by making this request:

```
PUT /api/v1/checkouts/:number/next.json
```

If the order doesn't have an assigned shipping rate, or you want to choose a different
shipping rate make the following request to select one and advance the order's state:

```
PUT /api/v1/checkouts/:number.json
```

With parameters such as these:

```json
{
  "order": {
    "shipments_attributes": {
      "0": {
        "selected_shipping_rate_id": 1,
        "id": 1
      }
    }
  }
}
```

<alert kind="note">
Please ensure you select a shipping rate for each shipment in the order. In the request above, the `selected_shipping_rate_id` should be the id of the shipping rate you want to use and the `id` should be the id of the shipment you are choosing this shipping rate for.
</alert>

## Confirm

To advance to the next state, `confirm`, the order will need to have a payment.
You can create a payment by passing in parameters such as this:

```json
{
  "order": {
    "payments_attributes": [{
      "payment_method_id": "1"
    }]
  },
  "payment_source": {
    "1": {
      "number": "4111111111111111",
      "month": "1",
      "year": "2017",
      "verification_value": "123",
      "name": "John Smith"
    }
  }
```

<alert kind="note">
  The numbered key in the `payment_source` hash directly corresponds to the
`payment_method_id` attribute within the `payment_attributes` key.
</alert>

You can also use an existing card for the order by submitting the credit card
id. See an example request:

```json
{
  "order": {
    "existing_card": "1"
  }
}
```

_Please note that for 2-2-stable checkout api the request body to submit a payment
via api/checkouts is slight different. See example:_

```json
{
  "order": {
    "payments_attributes": {
      "payment_method_id": "1"
    },
    "payment_source": {
      "1": {
        "number": "4111111111111111",
        "month": "1",
        "year": "2017",
        "verification_value": "123",
        "name": "John Smith"
      }
    }
  }
}
```

If the order already has a payment, you can advance it to the `confirm` state by making this request:

```
PUT /api/v1/checkouts/:number.json
```

For more information on payments, view the [payments documentation](payments).

### Response

<status code="200"></status>
```json
{
  ...
  "state": "confirm",
  ...
  "payments": [
    {
      "id": 3,
      "source_type": "Spree::CreditCard",
      "source_id": 2,
      "amount": "65.37",
      "display_amount": "$65.37",
      "payment_method_id": 1,
      "state": "checkout",
      "avs_response": null,
      "created_at": "2014-07-06T19:55:08.308Z",
      "updated_at": "2014-07-06T19:55:08.308Z",
      "number": "PNTS91GF",
      "payment_method": {
        "id": 1,
        "name": "Credit Card"
      },
      "source": {
        "id": 2,
        "month": "1",
        "year": "2017",
        "cc_type": null,
        "last_digits": "1111",
        "name": "John Smith"
      }
    }
  ],
  ...
}
```

## Complete

Now the order is ready to be advanced to the final state, `complete`. To accomplish this, make this request:

```
PUT /api/v1/checkouts/:number.json
```

You should get a 200 response with all the order info.
