---
title: Address
description: Use the Spree Commerce storefront API to access Address data.
---

## Show

Retrieve details about a particular address:

```text
GET /api/orders/1/addresses/1```

### Response

<%= headers 200 %>
<%= json(:address) %>

## Update

To update an address, make a request like this:

```text
PUT /api/orders/1/addresses/1?address[firstname]=Ryan```

This request will update the `firstname` field for an address to the value of \"Ryan\"

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

