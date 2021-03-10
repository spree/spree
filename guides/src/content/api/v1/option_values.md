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

<params params='[
  {
    "name": "ids",
    "description": "A comma-separated list of option value ids. Specifying this parameter will display the respective option values."
  }, {
    "name": "option_type_id",
    "description": "Specifying this parameter will display option values of respective option type."
  }
]'></params>

### Response

<status code="200"></status>
<json sample="option_values"></json>

## Search

To search for a specific option value, make a request like this:

```text
GET /api/v1/option_values?q[name_cont]=red
```

The searching API is provided through the Ransack gem which Spree depends on. The `name_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

### Response

<status code="200"></status>
<json sample="option_values"></json>

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

<status code="200"></status>
<json sample="option_value"></json>

## New

You can learn about the potential attributes (required and non-required) for a option value by making this request:

```text
GET /api/v1/option_values/new
```

### Response

<status code="200"></status>
```json
{
  "attributes": [
      "id", "name", "presentation", "option_type_name", "option_type_id",
      "option_type_presentation"
  ],
  "required_attributes": [
      "name", "presentation"
  ]
}
```

## Create

<alert type="admin_only" kind="danger"></alert>

To create a new option value through the API, make this request with the necessary parameters:

```text
POST /api/v1/option_values
```

For instance, a request to create a new option value called "sports" with a presentation value of "Sports" would look like this:

```text
POST /api/v1/option_values?option_value[name]=sports&option_value[presentation]=Sports
```

### Successful Response

<status code="201"></status>

### Failed Response

<status code="422"></status>
```json
{
  "error": "Invalid resource. Please fix errors and try again.",
  "errors": {
    "name": ["can't be blank"],
     "presentation": ["can't be blank"]
  }
}
```

## Update

<alert type="admin_only" kind="danger"></alert>

To update an option value's details, make this request with the necessary parameters:

```text
PUT /api/v1/option_values/1
```

For instance, to update an option value's name, send it through like this:

```text
PUT /api/v1/option_values/1?option_value[name]=sport&option_value[presentation]=Sport
```

### Successful Response

<status code="201"></status>

### Failed Response

<status code="422"></status>
```json
{
  "error": "Invalid resource. Please fix errors and try again.",
  "errors": {
    "name": ["can't be blank"],
    "presentation": ["can't be blank"]
  }
}
```


## Delete

<alert type="admin_only" kind="danger"></alert>

To delete an option value, make this request:

```text
DELETE /api/v1/option_values/1
```

This request removes an option value from database.

<status code="204"></status>
