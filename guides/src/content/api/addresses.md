---
title: Address
description: Use the Spree Commerce storefront API to access Address data.
---

## Show

Retrieve details about a particular address:

```text
GET /api/v1/orders/1/addresses/1
```

Order addresses through the API will only be visible to admins and the users who own particular orders related to that addresses.
If a user attempts to access an order address that does not belong to him, he
will be met with an authorization error.

Users may pass in the order's token in order to be authorized to view an order address:

```text
GET /api/v1/orders/1/addresses/1?order_token=abcdef123456
```

The `order_token` parameter will work for authorizing any action for an order address within Spree's API.

### Response

<status code="200"></status>
<json sample="address"></json>

## Update

To update an address, make a request like this:

```text
PUT /api/v1/orders/1/addresses/1?address[firstname]=Ryan
```

This request will update the `firstname` field for an address to the value of \"Ryan\"

### Response

<status code="200"></status>
<json sample="address" merge='{"firstname": "Ryan"}'></json>

Valid address fields are:

* firstname
* lastname
* company
* address1
* address2
* city
* zipcode
* phone
* alternative_phone
* country_id
* state_id
* state_name
