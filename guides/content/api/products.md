---
title: Products
description: Use the Spree Commerce storefront API to access Product data.
---

## Index

List products visible to the authenticated user. If the user is not an admin, they will only be able to see products which have an `available_on` date in the past. If the user is an admin, they are able to see all products.

```text
GET /api/products```

Products are paginated and can be iterated through by passing along a `page` parameter:

```text
GET /api/products?page=2```

### Parameters

show_deleted
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

## Search

To search for a particular product, make a request like this:

```text
GET /api/products?q[name_cont]=Spree```

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

```text
GET /api/products?q[s]=sku%20asc```

It is also possible to sort results using an associated object's field.

```text
GET /api/products?q[s]=shipping_category_name%20asc```

## Show

To view the details for a single product, make a request using that product\'s permalink:

```text
GET /api/products/a-product```

You may also query by the product\'s id attribute:

```text
GET /api/products/1```

Note that the API will attempt a permalink lookup before an ID lookup.

### Successful Response

<%= headers 200 %>
<%= json :product %>

### Not Found Response

<%= not_found %>

## New

You can learn about the potential attributes (required and non-required) for a product by making this request:

```text
GET /api/products/new```

### Response

<%= headers 200 %>
<%= json \
  :attributes => [
    :id, :name, :description, :price, :available_on, :permalink,
    :count_on_hand, :meta_description, :meta_keywords, :shipping_category_id, :taxon_ids
  ],
  :required_attributes => [:name, :price, :shipping_category_id]
 %>

## Create

<%= admin_only %>

To create a new product through the API, make this request with the necessary parameters:

```text
POST /api/products```

For instance, a request to create a new product called \"Headphones\" with a price of $100 would look like this:

```text
POST /api/products?product[name]=Headphones&product[price]=100&product[shipping_category_id]=1```

### Successful response

<%= headers 201 %>

### Failed response

<%= headers 422 %>
<%= json \
  :error => "Invalid resource. Please fix errors and try again.",
  :errors => {
    :name => ["can't be blank"],
    :price => ["can't be blank"],
    :shipping_category_id => ["can't be blank"]
  }
%>

## Update

<%= admin_only %>

To update a product\'s details, make this request with the necessary parameters:

```text
PUT /api/products/a-product```

For instance, to update a product\'s name, send it through like this:

```text
PUT /api/products/a-product?product[name]=Headphones```

### Successful response

<%= headers 201 %>

### Failed response

<%= headers 422 %>
<%= json \
  :error => "Invalid resource. Please fix errors and try again.",
  :errors => {
    :name => ["can't be blank"],
    :price => ["can't be blank"],
    :shipping_category_id => ["can't be blank"]
  }
%>

## Delete

<%= admin_only %>

To delete a product, make this request:

```text
DELETE /api/products/a-product```

This request, much like a typical product \"deletion\" through the admin interface, will not actually remove the record from the database. It simply sets the `deleted_at` field to the current time on the product, as well as all of that product\'s variants.

<%= headers 204 %>