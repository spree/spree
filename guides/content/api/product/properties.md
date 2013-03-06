---
title: Product Properties
---

# Product Properties API

<%= warning "Requests to this API will only succeed if the user making them has access to the underlying products. If the user is not an admin and the product is not available yet, users will receive a 404 response from this API." %>

## List product properties

List

Retrieve a list of all product properties for a product by making this request:

    GET /api/products/1/product_properties

Product properties are paginated and can be iterated through by passing along a `page` parameter:

    GET /api/products/1/product_propeties?page=2

### Parameters

page
: The page number of product property to display.

per_page
: The number of product properties to return per page

### Response

<%= headers 200 %>
<%= json(:product_property) do |h|
{ :product_properties => [h],
  :count => 10,
  :pages => 2,
  :current_page => 1 }
end %>

## Searching product properties

To search for a particular product property, make a request like this:

    GET /api/products/1/product_properties?q[property_name_cont]=bag

The searching API is provided through the Ransack gem which Spree depends on. The `property_name_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<%= headers 200 %>
<%= json(:product_property) do |h|
 { :product_properties => [h],
   :count => 10,
   :pages => 2,
   :current_page => 1 }
end %>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

    GET /api/products/1/product_properties?q[s]=property_name%20desc

## A single product property

To get information about a single product property, make a request like this:

    GET /api/products/1/product_properties/1

Or you can use a property's name:

    GET /api/products/1/product_properties/size

### Response

<%= headers 200 %>
<%= json(:product_property) %>

## Creating a product property

<%= admin_only %>

To create a new product property, make a request like this:

    POST /api/products/1/product_properties?product_property[property_name]=size&product_property[value]=10

If a property with that name does not already exist, then it will automatically be created.

### Response

<%= headers 201 %>
<%= json(:product_property) %>

## Updating a product property

To update an existing product property, make a request like this:

    PUT /api/products/1/product_properties/size?product_property[value]=10

You may also use a property's id if you know it:

    PUT /api/products/1/product_properties/1?product_property[value]=10

### Response

<%= headers 200 %>
<%= json(:product_property) %>

## Deleting a product property

To delete a product property, make a request like this:

    DELETE /api/prducts/1/product_porperties/size

<%= headers 204 %>

