---
title: Countries
description: Use the Spree Commerce storefront API to access Country data.
---

## Index

Retrieve a list of all countries by making this request:

```
GET /api/v1/countries
```

Countries are paginated and can be iterated through by passing along a `page` parameter:

```
GET /api/v1/countries?page=2
```

### Parameters

<params params='[
  {
    "name": "page",
    "description": "The page number of country to display."
  }, {
    "name": "per_page",
    "description": "The number of countries to return per page"
  }
]'></params>

### Response

<status code="200"></status>
<json sample="countries"></json>

## Search

To search for a particular country, make a request like this:

```
GET /api/v1/countries?q[name_cont]=united
```

The searching API is provided through the Ransack gem which Spree depends on. The `name_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<status code="200"></status>
<json sample="countries"></json>

Results can be returned in a specific order by specifying which field to sort by when making a request.

```
GET /api/v1/countries?q[s]=name%20desc
```

## Show

Retrieve details about a particular country:

```
GET /api/v1/countries/1
```

### Response

<status code="200"></status>
<json sample="country_with_state"></json>
