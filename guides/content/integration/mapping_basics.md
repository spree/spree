---
title: Mappings 
---

## Overview

Mappings represent a subscription for specific message types to an endpoint's service, for example `order:new` to the Mandrill Order Confirmation service. Mappings include all the details required to provide routing, filtering, uniqueness protection and failure handling.

## Parameters

Parameters are store specific configuration values that are included with each Service Request as part of the Message payload. A single message may contain any number of parameters (including zero).

There are two main types of parameters:

| Attribute            | Description               |
| :--------------------| :-------------------------|
| **Single Value**     | These represent single pieces of configuration data like API keys, email addresses, etc, using one of the following datatypes: string, integer, float and boolean.
| **Lists Value**      | Lists are special parameters generally used to hold lookup tables for matching data for disparate systems, for example shipping methods between Amazon and Spree Commerce


### Example List Parameter

```json
{
  "shipping_method.lookup": [
    { "standard": "US STANDARD",
      "expedited": "US STANDARD",
      "nextday": "OVERNIGHT",
      "secondday": "US 2 DAY EXPRESS"
    }
  ]
}
```

***
List parameters are arrays of hashes, this is intended to allow a single param to hold multiple related lookup tables for several mappings. 

For example a `shipping_method.lookup` param could hold two separate hashes for Amazon and one for Quickbooks.
***

## Identifiers

During the normal operation of the hub the same message can be created multiple times, for example a `shipment:ready` message is pushed for every update of an order where the order contains a shipment with a state of 'ready'. 

We do this to not limit the opportunity to act on a message to a single instance. In the case of the `shipment:ready` message you might not want to spend the shipment details to your 3PL until it has been marked as 'released'.

The first `shipment:ready` message would be generated when the `order:new` message gets processed, but at this point the `released_at` attribute would not be set (so a Filter would be used to prevent the mapping acting on the message). 

When the `released_at` attribute was set on your Spree Commerce storefront an `order:update` message would generate a second `shipment:ready` message which would meet the filter criteria and be sent to the endpoint.

Identifiers are then used to prevent duplicate messages from being sent to the same endpoint service more than once, by capturing key attributes from the message that indicate the message as unique (for example the order and shipment number in the case of a `shipment:ready` message). 

Identifiers have two key aspects:


| Attribute            | Description               |
| :--------------------| :-------------------------|
| Name                 | A variable name to hold the intended target value
| Path                 | An xpath style query to identify the target value

### Example Identifiers

```json
"identifiers": {
  "order_number": "payload.order.number",
  "shipment_number": "payload.shipment.number"
}
```

## Filters

Filters are very similar to Identifiers and are used to highlight attributes within a message and check them against a predefined value before allowing the message to route to an endpoint's service.

Filters are made up of four key values:

| Attribute            | Description               |
| :--------------------| :-------------------------|
| Path                 | An xpath style query to identify the target value
| Operator             | A predefined list of comparison checks (see list below)
| Value                | The static value to use in the comparison
| Match Rule           | 'any' or 'all' target values must pass comparison, default: 'all'

The following filter Operator are available:

| Attribute            | Description               |
| :--------------------| :-------------------------|
| Equal (eq)           | Does a direct string comparison of the two values (==)
| Not Equal (neq)      | Opposite of above (!=)
| Greater than (gt)    | Converts both values to floats, and ensures the target value is greater than the static value (>)
| Less than (lt)       | Converts both values to floats, and ensures the target value is less than the static value (<)
| Begins With (begin)  | Ensures target values begins with the static value
| Contains (contains)  | Ensures target values contains the static value
| Ends With (end)      | Ensures target values ends with the static value
| Present (present)    | Ensures target values is not null, an empty string and does not == 'null'
| Empty (empty)        | Ensures target values is either null, an empty string or == 'null'
| Match (match)        | Static value must be a regex that matches on target value

### Example Filters

```json
"filters": [
  {
    "path": "payload.order.status",
    "operator": "eq",
    "value": "complete"
  },
  {
    "path": "payload.order.totals.tax",
    "operator": "gt",
    "value": "100"
  },
  {
    "path": "payload.order.shipments.*.items.*.sku",
    "operator": "eq",
    "value": "ROR-0001",
    "match_rule": "any"
  },
]
```

## Failures

Mappings provide two methods of handling a message when it has failed (i.e. the endpoint returns a non HTTP 200 response).

The default approach is to retry automatically using an exponential back-off algorithm (i.e. the time between retries increases after each failure).

For some endpoint services where retrying a message could have potentially negative side-effects, automatic retries can be disabled effectively parking the message and requiring human intervention to allow it to retry or be manually archived.
