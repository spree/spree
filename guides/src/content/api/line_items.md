---
title: Line Items
description: Use the Spree Commerce storefront API to access LineItem data.
---

## Create

To create a new line item, make a request like this:

    POST /api/v1/orders/R1234567/line_items?line_item[variant_id]=1&line_item[quantity]=1

This will create a new line item representing a single item for the variant with the id of 1.

### Response

<status code="201"></status>
<json sample="line_item"></json>

## Update

To update the information for a line item, make a request like this:

    PUT /api/v1/orders/R1234567/line_items/1?line_item[variant_id]=1&line_item[quantity]=1

This request will update the line item with the ID of 1 for the order, updating the line item's `variant_id` to 1, and its `quantity` 1.

### Response

<status code="200"></status>
<json sample="line_item" merge='{"quantity": 1}'></json>

## Delete

To delete a line item, make a request like this:

    DELETE /api/v1/orders/R1234567/line_items/1

### Response

<status code="204"></status>
