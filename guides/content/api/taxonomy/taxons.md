---
title: Taxons
---

# Taxons API

## List taxons

To get a list for all taxons underneath the root taxon for a taxonomy (and their immediate children) for a taxonomy, make this request:

    GET /api/taxonomies/1/taxons

### Response

<%= headers 200 %>
<%= json(:taxon_with_children) { |h| [h] } %>

## A single taxon

To see information about a taxon and its immediate children, make a request
like this:

    GET /api/taxonomies/1/taxons/1

### Response

<%= headers 200 %>
<%= json(:taxon_with_children) %>


## Creating a taxon

<%= admin_only %>

To create a taxon, make a request like this:

    POST /api/taxonomies/1/taxons

To create a new taxon with the name "Brands", make this request:

    POST /api/taxonomies/1/taxons?taxon[name]=Brands

### Response

<%= headers 201 %>
<%= json(:taxon_without_children) %>


## Updating a taxon

<%= admin_only %>

To update a taxon, make a request like this:

    PUT /api/taxonomies/1/taxons/1

For example, to update the taxon's name to "Brand", make this request:

    PUT /api/taxonomies/1/taxons/1?taxon[name]=Brand

### Response

<%= headers 200 %>
<%= json(:taxon_with_children) %>

## Deleting a taxon

<%= admin_only %>

To delete a taxon, make a request like this:

    DELETE /api/taxonomies/1/taxons/1

<%= warning "This will cause all child taxons to be deleted as well." %>

### Response

<%= headers 204 %>


