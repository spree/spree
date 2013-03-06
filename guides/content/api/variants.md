---
title: Variants
---

## List variants

To return a paginated list of all variants within the store, make this request:

    GET /api/variants

You can limit this to showing the variants for a particular product by passing through a product id:

    GET /api/products/1/variants
    # or
    GET /api/variants?product_id=1

### Parameters

show\_deleted
: **boolean** - `true` to show deleted variants, `false` to hide them. Default: `false`. **Only available to users with an admin role.**

page
: The page number of variants to display.

per_page
: The number of variants to return per page

### Response

<%= headers 200 %>
<%= json(:variant) do |h|
{ :variants => [h],
  :count => 25,
  :pages => 5,
  :current_page => 1 }
end %>

## Searching variants

To search for a particular variant, make a request like this:

    GET /api/variants?q[sku_cont]=foo

You can limit this to showing the variants for a particular product by passing through a product id:

    GET /api/products/1/variants?q[sku_cont]=foo
    # or
    GET /api/variants?product_id=1&q[sku_cont]=foo

The searching API is provided through the Ransack gem which Spree depends on. The `sku_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<%= headers 200 %>
<%= json(:variant) do |h|
 { :variants => [h],
   :count => 25,
   :pages => 5,
   :current_page => 1 }
end %>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

    GET /api/variants?q[s]=price%20asc

It is also possible to sort results using an associated object's field.

    GET /api/variants?q[s]=product_name%20asc

## A single variant

To view the details for a single variant, make a request using that variant\'s id, along with its `product_id`:

    GET /api/products/1/variants/1

### Successful Response

<%= headers 200 %>
<%= json :variant %>

### Not Found Response

<%= not_found %>

## Pre-creation of a variant

You can learn about the potential attributes (required and non-required) for a variant by making this request:

     GET /api/products/1/variants/new

### Response

<%= headers 200 %>
<%= json \
  :attributes => [
    :id, :name, :count_on_hand, :sku, :price, :weight, :height,
    :width, :depth, :is_master, :cost_price, :permalink
  ],
  :required_attributes => []
 %>

## Creating a new variant

<%= admin_only %>

To create a new variant for a product, make this request with the necessary parameters:

    POST /api/products/1/variants

For instance, a request to create a new variant with a SKU of 12345 and a price of 19.99 would look like this::

    POST /api/products/1/variants/?variant[sku]=12345&variant[price]=19.99

### Successful response

<%= headers 201 %>

### Failed response

<%= headers 422 %>
<%= json \
  :error => "Invalid resource. Please fix errors and try again.",
  :errors => {
  }
%>

## Updating a variant

<%= admin_only %>

To update a variant\'s details, make this request with the necessary parameters:

    PUT /api/products/1/variants/2

For instance, to update a variant\'s SKU, send it through like this:

    PUT /api/products/1/variants/2?variant[sku]=12345

### Successful response

<%= headers 201 %>

### Failed response

<%= headers 422 %>
<%= json \
  :error => "Invalid resource. Please fix errors and try again.",
  :errors => {
  }
%>

## Deleting a variant

<%= admin_only %>

To delete a variant, make this request:

    DELETE /api/products/1/variants/2

This request, much like a typical variant \"deletion\" through the admin interface, will not actually remove the record from the database. It simply sets the `deleted_at` field to the current time on the variant.

<%= headers 204 %>

