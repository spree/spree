---
title: Stock Movements
description: Use the Spree Commerce storefront API to access StockMovement data.
---

## Index

<%= admin_only %>

To return a paginated list of all stock movements for a stock location, make this request, passing the stock location id you wish to see stock items for:

```text
GET /api/stock_locations/1/stock_movements```

### Parameters

page
: The page number of stock movements to display.

per_page
: The number of stock movements to return per page

### Response

<%= headers 200 %>
<%= json(:stock_movement) do |h|
{ :stock_movements => [h],
  :count => 25,
  :pages => 5,
  :current_page => 1 }
end %>

## Search

<%= admin_only %>

To search for a particular stock movement, make a request like this:

```text
GET /api/stock_locations/1/stock_movements?q[quantity_eq]=10```

The searching API is provided through the Ransack gem which Spree depends on. The `quantity_eq` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<%= headers 200 %>
<%= json(:stock_movement) do |h|
 { :stock_movements => [h],
   :count => 25,
   :pages => 5,
   :current_page => 1 }
end %>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

```text
GET /api/stock_locations/1/stock_movements?q[s]=quantity%20asc```

## Show

<%= admin_only %>

To view the details for a single stock movement, make a request using that stock movement's id, along with its `stock_location_id`:

```text
GET /api/stock_locations/1/stock_movements/1```

### Successful Response

<%= headers 200 %>
<%= json :stock_movement %>

### Not Found Response

<%= not_found %>

## Create

<%= admin_only %>

To create a new stock movement for a stock location, make this request with the necessary parameters:

```text
POST /api/stock_locations/1/stock_movements```

For instance, a request to create a new stock movement with a quantity of 10, the action set to received, and a stock_item_id of 1 would look like this::

<%= json \
  :stock_movement => {
    :quantity => "10",
    :stock_item_id => "1",
    :action => "received"
  } %>

### Successful response

<%= headers 201 %>
<%= json(:stock_movement) %>

### Failed response

<%= headers 422 %>
<%= json \
  :error => "Invalid resource. Please fix errors and try again.",
  :errors => {
  }
%>

## Update

<%= admin_only %>

To update a stock movement's details, make this request with the necessary parameters:

```text
PUT /api/stock_locations/1/stock_movements/1```

For instance, to update a stock movement's quantity, send it through like this:

<%= json \
  :stock_movement => {
    :quantity => "30",
  } %>

### Successful response

<%= headers 201 %>
<%= json(:stock_movement) %>

### Failed response

<%= headers 422 %>
<%= json \
  :error => "Invalid resource. Please fix errors and try again.",
  :errors => {
  }
%>

## Delete

<%= admin_only %>

To delete a stock movement, make this request:

```text
DELETE /api/stock_locations/1/stock_movement/1```

### Response

<%= headers 204 %>
