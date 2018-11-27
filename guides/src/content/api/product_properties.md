---
title: Product Properties
description: Use the Spree Commerce storefront API to access ProductProperty data.
---

<alert kind="warning">
  Requests to this API will only succeed if the user making them has access to the underlying products. If the user is not an admin and the product is not available yet, users will receive a 404 response from this API.
</alert>

## List

Retrieve a list of all product properties for a product by making this request:

    GET /api/v1/products/1/product_properties

Product properties are paginated and can be iterated through by passing along a `page` parameter:

    GET /api/v1/products/1/product_properties?page=2

### Parameters

<params params='[
  {
    "name": "page",
    "description": "The page number of product properties to display."
  }, {
    "name": "per_page",
    "description": "The number of product properties to return per page"
  }
]'></params>

### Response

<status code="200"></status>
<json sample="product_properties"></json>

## Search

To search for a particular product property, make a request like this:

    GET /api/v1/products/1/product_properties?q[property_name_cont]=bag

The searching API is provided through the Ransack gem which Spree depends on. The `property_name_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<status code="200"></status>
<json sample="product_properties"></json>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

    GET /api/v1/products/1/product_properties?q[s]=property_name%20desc

## Show

To get information about a single product property, make a request like this:

    GET /api/v1/products/1/product_properties/1

Or you can use a property's name:

    GET /api/v1/products/1/product_properties/size

### Response

<status code="200"></status>
<json sample="product_property"></json>

## Create

<alert type="admin_only" kind="danger"></alert>

To create a new product property, make a request like this:

    POST /api/v1/products/1/product_properties?product_property[property_name]=size&product_property[value]=10

If a property with that name does not already exist, then it will automatically be created.

### Response

<status code="201"></status>
<json sample="product_property"></json>

## Update

<alert type="admin_only" kind="danger"></alert>

To update an existing product property, make a request like this:

    PUT /api/v1/products/1/product_properties/size?product_property[value]=10

You may also use a property's id if you know it:

    PUT /api/v1/products/1/product_properties/1?product_property[value]=10

### Response

<status code="200"></status>
<json sample="product_property"></json>

## Delete

<alert type="admin_only" kind="danger"></alert>

To delete a product property, make a request like this:

    DELETE /api/v1/products/1/product_properties/size

<status code="204"></status>
