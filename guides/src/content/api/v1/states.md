---
title: States
description: Use the Spree Commerce storefront API to access State data.
---

## Index

To get a list of states within Spree, make a request like this:

```text
GET /api/v1/states
```

States are paginated and can be iterated through by passing along a `page`
parameter:

```text
GET /api/v1/states?page=2
```

As well as a `per_page` parameter to control how many results will be returned:

```text
GET /api/v1/states?per_page=100
```

You can scope the states by country by passing along a `country_id` parameter
too:

```text
GET /api/v1/states?country_id=1
```

### Response

<status code="200"></status>
<json sample="states"></json>

## Show

To find out about a single state, make a request like this:

```text
GET /api/v1/states/1
```

### Response

<status code="200"></status>
<json sample="state"></json>
