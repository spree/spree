---
title: Stock Locations
description: Use the Spree Commerce storefront API to access StockLocation data.
---

## Index

<%= admin_only %>

To get a list of stock locations, make this request:

```text
GET /api/stock_locations```

Stock locations are paginated and can be iterated through by passing along a `page` parameter:

```text
GET /api/stock_locations?page=2```

### Parameters

page
: The page number of stock location to display.

per_page
: The number of stock locations to return per page

### Response

<%= headers 200 %>
<%= json(:stock_location) do |h|
{ :stock_locations => [h],
  :count => 5,
  :pages => 1,
  :current_page => 1 }
end %>

## Search

<%= admin_only %>

To search for a particular stock location, make a request like this:

```text
GET /api/stock_locations?q[name_cont]=default```

The searching API is provided through the Ransack gem which Spree depends on. The `name_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<%= headers 200 %>
<%= json(:stock_location) do |h|
{ :stock_locations => [h],
  :count => 5,
  :pages => 1,
  :current_page => 1 }
end %>

## Show

<%= admin_only %>

To get information for a single stock location, make this request:

```text
GET /api/stock_locations/1```

### Response

<%= headers 200 %>
<%= json(:stock_location) %>

## Create

<%= admin_only %>

To create a stock location, make a request like this:

```text
POST /api/stock_locations```

Assuming in this instance that you want to create a stock location with a name of `East Coast`, send through the parameters like this:

<%= json \
  :stock_location => {
    :name => "East Coast",
    :action => "true"
  } %>

### Response

<%= headers 201 %>
<%= json(:stock_location) %>

## Update

<%= admin_only %>

To update a stock location, make a request like this:

```text
PUT /api/stock_locations/1```

To update stock location information, use parameters like this:

<%= json \
  :stock_location => {
    :name => "North Pole",
    :action => "false"
  } %>

### Response

<%= headers 200 %>
<%= json(:stock_location) %>

## Delete

<%= admin_only %>

To delete a stock location, make a request like this:

```text
DELETE /api/stock_locations/1```

This request will also delete any related `stock item` records.

### Response

<%= headers 204 %>
