---
title: Stock Items
description: Use the Spree Commerce storefront API to access StockItem data.
---

## Index

<%= admin_only %>

To return a paginated list of all stock items for a stock location, make this request, passing the stock location id you wish to see stock items for:

```text
GET /api/v1/stock_locations/1/stock_items```

### Parameters

page
: The page number of stock items to display.

per_page
: The number of stock items to return per page

### Response

<%= headers 200 %>
<%= json(:stock_item) do |h|
{ stock_items: [h],
  count: 25,
  current_page: 1,
  pages: 5 }
end %>

## Search

<%= admin_only %>

To search for a particular stock item, make a request like this:

```text
GET /api/v1/stock_locations/1/stock_items?q[variant_id_eq]=10```

The searching API is provided through the Ransack gem which Spree depends on. The `variant_id_eq` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<%= headers 200 %>
<%= json(:stock_item) do |h|
 { stock_items: [h],
   count: 25,
   current_page: 1,
   pages: 5 }
end %>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

```text
GET /api/v1/stock_locations/1/stock_items?q[s]=variant_id%20asc```

## Show

<%= admin_only %>

To view the details for a single stock item, make a request using that stock item's id, along with its `stock_location_id`:

```text
GET /api/v1/stock_locations/1/stock_items/2```

### Successful Response

<%= headers 200 %>
<%= json :stock_item %>

### Not Found Response

<%= not_found %>

## Create

<%= admin_only %>

To create a new stock item for a stock location, make this request with the necessary parameters:

```text
POST /api/v1/stock_locations/1/stock_items```

For instance, a request to create a new stock item with a count_on_hand of 10 and a variant_id of 1 would look like this::

<%= json \
  stock_item: {
    count_on_hand: "10",
    variant_id: "1",
    backorderable: "true"
  } %>

### Successful response

<%= headers 201 %>
<%= json(:stock_item) %>

### Failed response

<%= headers 422 %>
<%= json \
  error: "Invalid resource. Please fix errors and try again.",
  errors: {
  }
%>

## Update

<%= admin_only %>

Note that using this endpoint, count_on_hand <strong>IS APPENDED</strong> to its current value.

Sending a request with a negative count_on_hand <strong>WILL SUBSTRACT</strong> the current value.

To force a value for count_on_hand, include force: true in your request, this will replace the current
value as it's stored in the database.

To update a stock item's details, make this request with the necessary parameters.

```text
PUT /api/v1/stock_locations/1/stock_items/2```

For instance, to update a stock item's count_on_hand, send it through like this:

<%= json \
  stock_item: {
    count_on_hand: "30",
  } %>

Or alternatively with the force attribute to replace the current count_on_hand with a new value:

<%= json \
  stock_item: {
    count_on_hand: "30",
    force: true,
  } %>

### Successful response

<%= headers 201 %>
<%= json(:stock_item) do |h|
  h.merge("count_on_hand" => 30)
end %>

### Failed response

<%= headers 422 %>
<%= json \
  error: "Invalid resource. Please fix errors and try again.",
  errors: {
  }
%>

## Delete

<%= admin_only %>

To delete a stock item, make this request:

```text
DELETE /api/v1/stock_locations/1/stock_items/2```

### Response

<%= headers 204 %>
