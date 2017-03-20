---
title: Taxonomies
description: Use the Spree Commerce storefront API to access Taxonomy data.
---

## Index

To get a list of all the taxonomies, including their root nodes and the
immediate children for the root node, make a request like this:

```text
GET /api/v1/taxonomies```

### Parameters

page
: The page number of taxonomy to display.

per_page
: The number of taxonomies to return per page

set
: Displays the complete expanded taxonomy tree if set to ``nested``.

### Response

<%= headers 200 %>
<%= json(:taxonomy) do |h|
{ taxonomies: [h],
  count: 25,
  current_page: 1,
  pages: 5 }
end %>

## Search

To search for a particular taxonomy, make a request like this:

```text
GET /api/v1/taxonomies?q[name_cont]=brand```

The searching API is provided through the Ransack gem which Spree depends on. The `name_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<%= headers 200 %>
<%= json(:taxonomy) do |h|
 { taxonomies: [h],
   count: 5,
   current_page: 1,
   pages: 2 }
end %>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

```text
GET /api/v1/taxonomies?q[s]=name%20asc```

It is also possible to sort results using an associated object's field.

```text
GET /api/v1/taxonomies?q[s]=root_name%20desc```

## Show

To get information for a single taxonomy, including its root node and the immediate children of the root node, make a request like this:

```text
GET /api/v1/taxonomies/1```

### Response

<%= headers 200 %>
<%= json(:taxonomy) %>

## Create

<%= admin_only %>

To create a taxonomy, make a request like this:

```text
POST /api/v1/taxonomies```

For instance, if you want to create a taxonomy with the name \"Brands\", make
this request:

```text
POST /api/v1/taxonomies?taxonomy[name]=Brand```

If you\'re creating a taxonomy without a root taxon, a root taxon will automatically be
created for you with the same name as the taxon.

### Response

<%= headers 201 %>
<%= json(:new_taxonomy) %>

## Update

<%= admin_only %>

To update a taxonomy, make a request like this:

```text
PUT /api/v1/taxonomies/1```

For instance, to update a taxonomy\'s name, make this request:

```text
PUT /api/v1/taxonomies/1?taxonomy[name]=Brand```

### Response

<%= headers 200 %>
<%= json(:taxonomy) %>

## Delete

<%= admin_only %>

To delete a taxonomy, make a request like this:

```text
DELETE /api/v1/taxonomies/1```

### Response

<%= headers 204 %>

## List taxons

To get a list for all taxons underneath the root taxon for a taxonomy (and their children) for a taxonomy, make this request:

    GET /api/v1/taxonomies/1/taxons

### Parameters

without_children
: Displays only immediate children of taxons if set to ``true``.

### Response

<%= headers 200 %>
<%= json(:taxon_with_children) do |h|
  { "taxons" => [h],
    "count" => 7,
    "total_count" => 7,
    "current_page" => 1,
    "per_page" => 25,
    "pages" => 1
  }
end %>

## A single taxon

To see information about a taxon and its immediate children, make a request
like this:

    GET /api/v1/taxonomies/1/taxons/1

### Response

<%= headers 200 %>
<%= json(:taxon_with_children) %>


## Taxon Create

<%= admin_only %>

To create a taxon, make a request like this:

    POST /api/v1/taxonomies/1/taxons

To create a new taxon with the name "Brands", make this request:

    POST /api/v1/taxonomies/1/taxons?taxon[name]=Brands

### Response

<%= headers 201 %>
<%= json(:taxon_without_children) do |h|
  h.merge({
    "name" => "Brands",
    "pretty_name" => "Brands",
    "permalink" => "brands/brands",
    "meta_title" => "Brands",
    "meta_description" => "Brands"
  })
end %>


## Taxon Update

<%= admin_only %>

To update a taxon, make a request like this:

    PUT /api/v1/taxonomies/1/taxons/1

For example, to update the taxon's name to "Brand", make this request:

    PUT /api/v1/taxonomies/1/taxons/1?taxon[name]=Brand

### Response

<%= headers 200 %>
<%= json(:taxon_with_children) do |h|
  h.merge({
    "name" => "Brands",
    "pretty_name" => "Brands",
    "permalink" => "brands/brands",
    "meta_title" => "Brands",
    "meta_description" => "Brands"
  })
end %>

## Taxon Delete

<%= admin_only %>

To delete a taxon, make a request like this:

    DELETE /api/v1/taxonomies/1/taxons/1

<%= warning "This will cause all child taxons to be deleted as well." %>

### Response

<%= headers 204 %>
