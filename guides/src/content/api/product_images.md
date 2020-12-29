---
title: Product Images
description: Use the Spree Commerce storefront API to access Product Images data.
---

## Index

List product images visible to the authenticated user. If the user is an admin, they are able to see all images.

You may make a request using product\'s permalink or id attribute.

Note that the API will attempt a permalink lookup before an ID lookup.

```text
GET /api/v1/products/a-product/images
```

### Response

<status code="200"></status>
<json sample="images"></json>

## Show

```text
GET /api/v1/products/a-product/images/1
```

### Successful Response

<status code="200"></status>
<json sample="image"></json>

### Not Found Response

<alert type="not_found"></alert>

## New

You can learn about the potential attributes (required and non-required) for a product's image by making this request:

```text
GET /api/v1/products/a-product/images/new
```

### Response

<status code="200"></status>
```json
{
  "attributes": [
    "id", "position", "attachment_content_type", "attachment_file_name", "type",
    "attachment_updated_at", "attachment_width", "attachment_height", "alt"
  ],
  "required_attributes": []
}
```

## Create

<alert type="admin_only" kind="danger"></alert>

To upload a new image through the API, make this request with the necessary parameters:

```text
POST /api/v1/products/a-product/images
```

For instance, a request using cURL will look like this:

```bash
curl -i -X POST \
  -H "X-Spree-Token: USER_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F "image[attachment]=@/absolute/path/to/image.jpg" \
  -F "type=image/jpeg" \
  http://localhost:3000/api/v1/products/a-product/images
```

### Successful response

<status code="201"></status>

## Update

<alert type="admin_only" kind="danger"></alert>

To update an image, make this request with the necessary parameters:

```text
PUT /api/v1/products/a-product/images/1
```

A cURL request to update a product image would look like this:

```bash
curl -i -X PUT \
  -H "X-Spree-Token: USER_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F "image[attachment]=@/new/path/to/image.jpg" \
  -F "type=image/jpeg" \
  http://localhost:3000/api/v1/products/a-product/images/1
```

### Successful response

<status code="201"></status>

## Delete

<alert type="admin_only" kind="danger"></alert>

To delete a product image, make this request:

```text
DELETE /api/v1/products/a-product/images/1
```

This request will remove the record from the database.

<status code="204"></status>
