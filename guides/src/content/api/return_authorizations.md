---
title: Return Authorizations
description: Use the Spree Commerce storefront API to access ReturnAuthorization data.
---

# Return Authorizations API

<%= admin_only %>

## Index

To list all return authorizations for an order, make a request like this:

    GET /api/v1/orders/R1234567/return_authorizations

Return authorizations are paginated and can be iterated through by passing along a `page` parameter:

    GET /api/v1/orders/R1234567/return_authorizations?page=2

### Parameters

page
: The page number of return authorization to display.

per_page
: The number of return authorizations to return per page

### Response

<%= headers 200 %>
<%= json(:return_authorization) do |h|
{ return_authorizations: [h],
  count: 2,
  current_page: 1,
  pages: 1 }
end %>

## Search

To search for a particular return authorization, make a request like this:

    GET /api/v1/orders/R1234567/return_authorizations?q[memo_cont]=damage

The searching API is provided through the Ransack gem which Spree depends on. The `memo_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

    GET /api/v1/orders/R1234567/return_authorizations?q[s]=amount%20asc

### Response

<%= headers 200 %>
<%= json(:return_authorization) do |h|
 { return_authorizations: [h],
   count: 1,
   current_page: 1,
   pages: 1 }
end %>

## Show

To get information for a single return authorization, make a request like this:

     GET /api/v1/orders/R1234567/return_authorizations/1

### Response

<%= headers 200 %>
<%= json(:return_authorization) %>

## Create

<%= admin_only %>

To create a return authorization, make a request like this:

     POST /api/v1/orders/R1234567/return_authorizations

For instance, if you want to create a return authorization with a number, make
above request with following parameters:

```text
{
  "order_id": "R1234567",
  "return_authorization": {
    "stock_location_id": 1,
    "return_authorization_reason_id": 2
  }
}
```

### Response

<%= headers 201 %>
<%= json(:return_authorization) %>

## Update

<%= admin_only %>

To update a return authorization, make a request like this:

     PUT /api/v1/orders/R1234567/return_authorizations/1

For instance, to update a return authorization's number, make this request:

     PUT /api/v1/orders/R1234567/return_authorizations/1?return_authorization[memo]=Broken

### Response

<%= headers 200 %>
<%= json(:return_authorization) do |h|
  h.merge("memo" => "Broken")
end %>

## Delete

<%= admin_only %>

To delete a return authorization, make a request like this:

    DELETE /api/v1/orders/R1234567/return_authorizations/1

### Response

<%= headers 204 %>
