---
title: Option Types
description: Use the Spree Commerce storefront API to access OptionType data.
---

## Index

Retrieve a list of option types by making this request:

``` text
  GET /api/v1/option_types
```
### Parameters

ids:
A comma-separated list of option type ids. Specifying this parameter will display the respective option types.

### Responses

<%= headers 200 %>
<%= json(:option_type){ |h| [h] } %>

## Search

To search for a specific option type, make a request like this:
```text
  GET /api/v1/option_types?q[name_cont]=color
```
The searching API is provided through the Ransack gem which Spree depends on. The `name_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

### Response

<%= headers 200 %>
<%= json(:option_type){ |h| [h] } %>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

```text
  GET /api/v1/option_types?q[s]=name%20asc
```

## Show

Retrieve details about a particular option type:
```text
  GET /api/v1/option_types/1
```

### Response

<%= headers 200 %>
<%= json(:option_type) %>
