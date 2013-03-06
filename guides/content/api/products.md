---
title: Products
---

List products visible to the authenticated user. If the user is not an admin, they will only be able to see products which have an `available_on` date in the past. If the user is an admin, they are able to see all products.

    GET /api/products

Products are paginated and can be iterated through by passing along a `page` parameter:

    GET /api/products?page=2

### Parameters

show\_deleted
: **boolean** - `true` to show deleted products, `false` to hide them. Default: `false`. **Only available to users with an admin role.**

page
: The page number of products to display.

per_page
: The number of products to return per page

### Response

<%= headers 200 %>
<%= json(:product) do |h|
{ :products => [h],
  :count => 25,
  :pages => 5,
  :current_page => 1 }
end %>

## Searching products

To search for a particular product, make a request like this:

    GET /api/products?q[name_cont]=Spree

The searching API is provided through the Ransack gem which Spree depends on. The `name_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<%= headers 200 %>
<%= json(:product) do |h|
{ :products => [h],
  :count => 25,
  :pages => 5,
  :current_page => 1 }
end %>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

    GET /api/products?q[s]=sku%20asc

It is also possible to sort results using an associated object's field.

    GET /api/products?q[s]=shipping_category_name%20asc

## A single product

To view the details for a single product, make a request using that product\'s permalink:

    GET /api/products/a-product

You may also query by the product\'s id attribute:

    GET /api/products/1

Note that the API will attempt a permalink lookup before an ID lookup.

### Successful Response

<%= headers 200 %>
<%= json :product %>

### Not Found Response

<%= not_found %>

## Pre-creation of a product

You can learn about the potential attributes (required and non-required) for a product by making this request:

     GET /api/products/new

### Response

<%= headers 200 %>
<%= json \
  :attributes => [
    :id, :name, :description, :price, :available_on, :permalink,
    :count_on_hand, :meta_description, :meta_keywords, :taxon_ids
  ],
  :required_attributes => [:name, :price]
 %>

## Creating a new product

<%= admin_only %>

To create a new product through the API, make this request with the necessary parameters:

    POST /api/products

For instance, a request to create a new product called \"Headphones\" with a price of $100 would look like this:

    POST /api/products?product[name]=Headphones&product[price]=100

### Successful response

<%= headers 201 %>

### Failed response

<%= headers 422 %>
<%= json \
  :error => "Invalid resource. Please fix errors and try again.",
  :errors => {
    :name => ["can't be blank"],
    :price => ["can't be blank"]
  }
%>

## Updating a product

<%= admin_only %>

To update a product\'s details, make this request with the necessary parameters:

    PUT /api/products/a-product

For instance, to update a product\'s name, send it through like this:

    PUT /api/products/a-product?product[name]=Headphones

### Successful response

<%= headers 201 %>

### Failed response

<%= headers 422 %>
<%= json \
  :error => "Invalid resource. Please fix errors and try again.",
  :errors => {
    :name => ["can't be blank"],
    :price => ["can't be blank"]
  }
%>

## Deleting a product

<%= admin_only %>

To delete a product, make this request:

    DELETE /api/products/a-product

This request, much like a typical product \"deletion\" through the admin interface, will not actually remove the record from the database. It simply sets the `deleted_at` field to the current time on the product, as well as all of that product\'s variants.

<%= headers 204 %>

