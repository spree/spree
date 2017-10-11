---
title: Option Values
description: Use the Spree Commerce storefront API to access OptionValue data.
---

## Index

Retrieve a list of option values by making this request:

``` text
GET /api/v1/option_values
```

### Parameters

ids
: A comma-separated list of option value ids. Specifying this parameter will display the respective option values.

option_type_id
: Specifying this parameter will display option values of respective option type.

### Response

<%= headers 200 %>
<%= json(:option_value){ |h| [h] } %>

## Search

To search for a specific option value, make a request like this:

```text
GET /api/v1/option_values?q[name_cont]=red
```

The searching API is provided through the Ransack gem which Spree depends on. The `name_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

### Response

<%= headers 200 %>
<%= json(:option_value){ |h| [h] } %>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

```text
GET /api/v1/option_values?q[s]=name%20asc
```

## Show

Retrieve details about a particular option value:

```text
GET /api/v1/option_values/1
```

### Response

<%= headers 200 %>
<%= json(:option_value) %>

## New

You can learn about the potential attributes (required and non-required) for a option value by making this request:

```text
GET /api/v1/option_values/new
```

### Response

<%= headers 200 %>
<%= json \
  "attributes": [
      "id", "name", "presentation", "option_type_name", "option_type_id",
      "option_type_presentation"
  ],
  "required_attributes": [
      "name", "presentation"
  ]
%>

## Create

<%= admin_only %>

To create a new option value through the API, make this request with the necessary parameters:

```text
POST /api/v1/option_values
```

For instance, a request to create a new option value called "sports" with a presentation value of "Sports" would look like this:

```text
POST /api/v1/option_values?option_value[name]=sports&option_value[presentation]=Sports
```

### Successful Response

<%= headers 201 %>

### Failed Response

<%= headers 422 %>
<%= json \
  error: "Invalid resource. Please fix errors and try again.",
  errors: {
    "name": ["can't be blank"],
     "presentation": ["can't be blank"]
  }
%>

## Update

<%= admin_only %>

To update an option value's details, make this request with the necessary parameters:

```text
PUT /api/v1/option_values/1
```

For instance, to update an option value's name, send it through like this:

```text
PUT /api/v1/option_values/1?option_value[name]=sport&option_value[presentation]=Sport
```

### Successful Response

<%= headers 201 %>

### Failed Response

<%= headers 422 %>
<%= json \
  error: "Invalid resource. Please fix errors and try again.",
  errors: {
    name: ["can't be blank"],
    presentation: ["can't be blank"]
  }
%>


## Delete

<%= admin_only %>

To delete an option value, make this request:

```text
DELETE /api/v1/option_values/1
```

This request removes an option value from database.

<%= headers 204 %>
