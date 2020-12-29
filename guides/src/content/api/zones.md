---
title: Zones
description: Use the Spree Commerce storefront API to access Zone data.
---

## Index

To get a list of zones, make this request:

```text
GET /api/v1/zones
```

Zones are paginated and can be iterated through by passing along a `page` parameter:

```text
GET /api/v1/zones?page=2
```

### Parameters

<params params='[
  {
    "name": "page",
    "description": "The page number of zone to display."
  }, {
    "name": "per_page",
    "description": "The number of zones to return per page"
  }
]'></params>

### Response

<status code="200"></status>
<json sample="zones"></json>

## Search

To search for a particular zone, make a request like this:

```text
GET /api/v1/zones?q[name_cont]=north
```

The searching API is provided through the Ransack gem which Spree depends on. The `name_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<status code="200"></status>
<json sample="zones"></json>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

```text
GET /api/v1/zones?q[s]=name%20desc
```

## Show

To get information for a single zone, make this request:

```text
GET /api/v1/zones/1
```

### Response

<status code="200"></status>
<json sample="zone"></json>

## Create

<alert type="admin_only" kind="danger"></alert>

To create a zone, make a request like this:

```text
POST /api/v1/zones
```

Assuming in this instance that you want to create a zone containing
a zone member which is a `Spree::Country` record with the `id` attribute of 1, send through the parameters like this:

```json
{
  "zone": {
    "name": "North Pole",
    "zone_members": [
      {
        "zoneable_type": "Spree::Country",
        "zoneable_id": 1
      }
    ]
  }
}
```

### Response

<status code="201"></status>
<json sample="zone" merge='{"name": "North Pole"}'></json>

## Update

<alert type="admin_only" kind="danger"></alert>

To update a zone, make a request like this:

```text
PUT /api/v1/zones/1
```

To update zone and zone member information, use parameters like this:

```json
{
  "zone": {
    "name": "North Pole",
    "zone_members": [
      {
        "zoneable_type": "Spree::Country",
        "zoneable_id": 1
      }
    ]
  }
}
```

### Response

<status code="200"></status>
<json sample="zone"></json>

## Delete

<alert type="admin_only" kind="danger"></alert>

To delete a zone, make a request like this:

```text
DELETE /api/v1/zones/1
```

This request will also delete any related `zone_member` records.

### Response

<status code="204"></status>
