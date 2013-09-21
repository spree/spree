---
title: States
description: Use the Spree Commerce storefront API to access State data.
---

## Index

To get a list of states within Spree, make a request like this:

```text
GET /api/states```

States are paginated and can be iterated through by passing along a `page`
parameter:

```text
GET /api/states?page=2```

As well as a `per_page` parameter to control how many results will be returned:

```text
GET /api/states?per_page=100```

You can scope the states by country by passing along a `country_id` parameter
too:

```text
GET /api/states?country_id=1```

### Response

<%= headers 200 %>
<%= json(:state) do |h|
{ :states => [h],
  :count => 25,
  :pages => 5,
  :current_page => 1 }
end %>

## Show

To find out about a single state, make a request like this:

```text
GET /api/states/1```

### Response

<%= headers 200 %>
<%= json(:state) %>
