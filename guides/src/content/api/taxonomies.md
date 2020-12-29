---
title: Taxonomies
description: Use the Spree Commerce storefront API to access Taxonomy data.
---

## Index

To get a list of all the taxonomies, including their root nodes and the
immediate children for the root node, make a request like this:

```text
GET /api/v1/taxonomies
```

### Parameters

<params params='[
  {
    "name": "page",
    "description": "The page number of taxonomy to display."
  }, {
    "name": "per_page",
    "description": "The number of taxonomies to return per page"
  }, {
    "name": "set",
    "description": "Displays the complete expanded taxonomy tree if set to `nested`."
  }
]'></params>

### Response

<status code="200"></status>
<json sample="taxonomies"></json>

## Search

To search for a particular taxonomy, make a request like this:

```text
GET /api/v1/taxonomies?q[name_cont]=brand
```

The searching API is provided through the Ransack gem which Spree depends on. The `name_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<status code="200"></status>
<json sample="taxonomies"></json>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

```text
GET /api/v1/taxonomies?q[s]=name%20asc
```

It is also possible to sort results using an associated object's field.

```text
GET /api/v1/taxonomies?q[s]=root_name%20desc
```

## Show

To get information for a single taxonomy, including its root node and the immediate children of the root node, make a request like this:

```text
GET /api/v1/taxonomies/1
```

### Response

<status code="200"></status>
<json sample="taxonomy"></json>

## Create

<alert type="admin_only" kind="danger"></alert>

To create a taxonomy, make a request like this:

```text
POST /api/v1/taxonomies
```

For instance, if you want to create a taxonomy with the name \"Brands\", make
this request:

```text
POST /api/v1/taxonomies?taxonomy[name]=Brand
```

If you\'re creating a taxonomy without a root taxon, a root taxon will automatically be
created for you with the same name as the taxon.

### Response

<status code="201"></status>
<json sample="new_taxonomy"></json>

## Update

<alert type="admin_only" kind="danger"></alert>

To update a taxonomy, make a request like this:

```text
PUT /api/v1/taxonomies/1
```

For instance, to update a taxonomy\'s name, make this request:

```text
PUT /api/v1/taxonomies/1?taxonomy[name]=Brand
```

### Response

<status code="200"></status>
<json sample="taxonomy"></json>

## Delete

<alert type="admin_only" kind="danger"></alert>

To delete a taxonomy, make a request like this:

```text
DELETE /api/v1/taxonomies/1
```

### Response

<status code="204"></status>

## List taxons

To get a list for all taxons underneath the root taxon for a taxonomy (and their children) for a taxonomy, make this request:

    GET /api/v1/taxonomies/1/taxons

### Parameters

<params params='[
  {
    "name": "without_children",
    "description": "Displays only immediate children of taxons if set to `true`."
  }
]'></params>

### Response

<status code="200"></status>
<json sample="taxons_with_children"></json>

## A single taxon

To see information about a taxon and its immediate children, make a request
like this:

    GET /api/v1/taxonomies/1/taxons/1

### Response

<status code="200"></status>
<json sample="taxon_with_children"></json>

## Taxon Create

<alert type="admin_only" kind="danger"></alert>

To create a taxon, make a request like this:

    POST /api/v1/taxonomies/1/taxons

To create a new taxon with the name "Brands", make this request:

    POST /api/v1/taxonomies/1/taxons?taxon[name]=Brands

### Response

<status code="201"></status>
<json sample="taxon" merge='{
    "name": "Brands",
    "pretty_name": "Brands",
    "permalink": "brands/brands",
    "meta_title": "Brands",
    "meta_description": "Brands"
  }'></json>

## Taxon Update

<alert type="admin_only" kind="danger"></alert>

To update a taxon, make a request like this:

    PUT /api/v1/taxonomies/1/taxons/1

For example, to update the taxon's name to "Brand", make this request:

    PUT /api/v1/taxonomies/1/taxons/1?taxon[name]=Brand

### Response

<status code="200"></status>
<json sample="taxon_with_children" merge='{
    "name": "Brands",
    "pretty_name": "Brands",
    "permalink": "brands/brands",
    "meta_title": "Brands",
    "meta_description": "Brands"
  }'></json>

## Taxon Delete

<alert type="admin_only" kind="danger"></alert>

To delete a taxon, make a request like this:

    DELETE /api/v1/taxonomies/1/taxons/1

<alert kind="warning">
  This will cause all child taxons to be deleted as well.
</alert>

### Response

<status code="204"></status>
