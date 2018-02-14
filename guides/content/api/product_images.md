---
title: Product Images
description: Use the Spree Commerce storefront API to access Product Images data.
---

## Index

List product images visible to the authenticated user. If the user is an admin, they are able to see all images.

You may make a request using product\'s permalink or id attribute.

Note that the API will attempt a permalink lookup before an ID lookup.

```text
GET /api/v1/products/a-product/images```

### Response

<%= headers 200 %>
<%= json(:image) do |h|
{ images: [h] }
end %>

## Show

```text
GET /api/v1/products/a-product/images/1```

### Successful Response

<%= headers 200 %>
<%= json :image %>

### Not Found Response

<%= not_found %>

## New

You can learn about the potential attributes (required and non-required) for a product's image by making this request:

```text
GET /api/v1/products/a-product/images/new```

### Response

<%= headers 200 %>
<%= json \
  attributes: [
    :id, :position, :attachment_content_type, :attachment_file_name, :type,
    :attachment_updated_at, :attachment_width, :attachment_height, :alt
  ],
  required_attributes: []
 %>

## Create

<%= admin_only %>

To upload a new image through the API, make this request with the necessary parameters:

```text
POST /api/v1/products/a-product/images```

For instance, a request using cURL will look like this:

```text
curl -i -X POST \
  -H "X-Spree-Token: USER_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F "image[attachment]=@/absolute/path/to/image.jpg" \
  -F "type=image/jpeg" \
  http://localhost:3000/api/v1/products/a-product/images```

### Successful response

<%= headers 201 %>

## Update

<%= admin_only %>

To update an image, make this request with the necessary parameters:

```text
PUT /api/v1/products/a-product/images/1```

A cURL request to update a product image would look like this:

```text
curl -i -X PUT \
  -H "X-Spree-Token: USER_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F "image[attachment]=@/new/path/to/image.jpg" \
  -F "type=image/jpeg" \
  http://localhost:3000/api/v1/products/a-product/images/1```

### Successful response

<%= headers 201 %>

## Delete

<%= admin_only %>

To delete a product image, make this request:

```text
DELETE /api/v1/products/a-product/images/1```

This request will remove the record from the database.

<%= headers 204 %>
