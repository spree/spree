---
title: Spree Endpoint
---

## Overview

The Spree endpoint is the endpoint that handles all the interaction between the hub and Spree stores. It provides a variety of actions for monitoring different entities, which will be described below.

+++
The source code for the [Spree Endpoint](https://github.com/spree/spree_endpoint/) is available on Github.
+++

## Services

### Order Poll

When sent a "spree:order:poll" message to /orders/poller, the endpoint fetches new orders from Spree.

####Request

```
{
  "store_name": "ABC Widgets",
  "message": "spree:order:poll",
  "created_at": "2013-09-26T20:26:17Z",
  "completed_at": "2013-09-26T20:26:24Z",
  "consumer_class": "Augury::Consumers::Remote",
  "attempt_at": "2013-09-26T20:26:20Z",
  "attempts": 0,
  "mapping": {
    "enabled": true,
    "filters": [ ],
    "identifiers": { },
    "messages": [
      "spree:order:poll"
    ],
    "name": "spree.order_poll",
    "options": {
      "retries_allowed": true
    },
    "parameters": [ ],
    "required": true,
    "store_id": {
      "$oid": "123"
    },
    "token": "abc123",
    "url": "http://ep-spree.spree.fm/orders/poller",
    "usage": {
      "1hr": 6,
      "6hr": 36,
      "24hr": 144,
      "3d": 1937
    },
    "usage_updated_at": "2013-09-26T20:24:19Z",
    "consumer": "Augury::Consumers::Remote"
  },
  "source": "accepted"
}
```

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| api_url | Your Spree Store's API URL | http://demostore.com/api/ |
| api_key | API Key for an Admin User | dj20492dhjkdjeh2838w7 |
| api_version | Spree Store Version | 2.0 |
| order_poll.last_updated_at | Import all orders after this timestamp | 2013-09-24T19:50:00Z |
| order_poll.per_page | Number of orders to poll per page (max 50) | 10 |

#### Response

~~~
TODO: fill in response
~~~

### Order Lock

When sent an "order:ship" message, the endpoint Locks the order in a Spree store, preventing the admin from editing it.


####Request

~~~
TODO: fill in request
~~~

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| api_url | Your Spree Store's API URL | http://demostore.com/api/ |
| api_key | API Key for an Admin User | dj20492dhjkdjeh2838w7 |
| api_version | Spree Store Version | 2.0 |

#### Response

~~~
TODO: fill in response
~~~

### Order Count on Hand

When sent an "stock:change" message, the endpoint updates the count on hand for a product in a Spree store.


####Request

~~~
TODO: fill in request
~~~

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| api_url | Your Spree Store's API URL | http://demostore.com/api/ |
| api_key | API Key for an Admin User | dj20492dhjkdjeh2838w7 |
| api_version | Spree Store Version | 2.0 |
| stock_location_id | ID of Stock Location in Spree | 2 |

#### Response

~~~
TODO: fill in response
~~~

### Order Import

When sent an "order:import" message, the endpoint imports an order into the Spree store.


####Request

~~~
TODO: fill in request
~~~

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| api_url | Your Spree Store's API URL | http://demostore.com/api/ |
| api_key | API Key for an Admin User | dj20492dhjkdjeh2838w7 |
| api_version | Spree Store Version | 2.0 |
| truncate_address_address1 | Maximum Length of Address1 Field | 255 |

#### Response

~~~
TODO: fill in response
~~~

### Payments Capture

When sent an "order:capture" message, the endpoint captures the payment on an order.

####Request

~~~
TODO: fill in request
~~~

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| api_url | Your Spree Store's API URL | http://demostore.com/api/ |
| api_key | API Key for an Admin User | dj20492dhjkdjeh2838w7 |
| api_version | Spree Store Version | 2.0 |

#### Response

~~~
TODO: fill in response
~~~

### Inventory Unit Service

When sent an "shipment:confirm" message, the endpoint logs serial numbers on an inventory unit based on the external_ref provided.

####Request

~~~
TODO: fill in request
~~~

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| api_url | Your Spree Store's API URL | http://demostore.com/api/ |
| api_key | API Key for an Admin User | dj20492dhjkdjeh2838w7 |
| api_version | Spree Store Version | 2.0 |

#### Response

~~~
TODO: fill in response
~~~

### Shipments Dispatch

When sent an "shipment:confirm" message, the endpoint marks a shipment as shipped, and adds tracking details.

####Request

~~~
TODO: fill in request
~~~

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| api_url | Your Spree Store's API URL | http://demostore.com/api/ |
| api_key | API Key for an Admin User | dj20492dhjkdjeh2838w7 |
| api_version | Spree Store Version | 2.0 |

#### Response

~~~
TODO: fill in response
~~~

### Stock Transfer Poller

When sent an "spree:stock_transfer:poll" message, the endpoint polls the Spree store for changes in Stock Transfers.

####Request

~~~
TODO: fill in request
~~~

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| api_url | Your Spree Store's API URL | http://demostore.com/api/ |
| api_key | API Key for an Admin User | dj20492dhjkdjeh2838w7 |
| api_version | Spree Store Version | 2.0 |
| stock_transfer_poller.last_updated_at | Import all stock transfers after this timestamp | 2013-09-24T19:50:00Z |

#### Response

~~~
TODO: fill in response
~~~

### Stock Change

This message will change the ```count_on_hand``` for a ```Spree::Variant``` based on the provided sku and the quantity. The quantity can be negative!. The behaviour is a bit different between Spree versions. See tables below.

Basically it's impossible to create any backorders for a Spree 1.3 store since the logic is tied to ```Orders``` and ```InventoryUnits```. An ```InvalidQuantityException``` will be raised when that's happening.

#### Spree 1-3-stable store overview

| Original Count | Quantity | Count Result |
| :--------------| :------- | :------------|
| 6 | 20 | 26
| 6 | -4 | 2
| 6 | -7 | Exception!
| -6| 20 | 14
| -6| -1 | Exception!
| -6| -7 | Exception!


#### Spree 2-0-stable store overview

| Original Count | Quantity | Count Result |
| :--------------| :------- | :------------|
| 6 | 20 | 26
| 6 | -4 | 2
| 6 | -7 | -1
| -6| 20 | 14
| -6| -1 | -7
| -6| -7 | -13

#### Forcing the quantity.

It's possible to force the quantity, when the ```spree.force_quantity``` is set to true (it's false by default!) the provided quantity will be the new ```count_on_hand```. For a Spree 1-3-stable store an ```InvalidQuantityException``` will be raised when the quantity is negative.


####Request

---stock_change.json---

```json
{
  "message": "stock:change",
  "payload": {
  "sku": "APC-00001",
  "quantity": 5
  }
}
```

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| spree.force_quantity | forcing the count_on_hand to the supplied quantity | true |
| spree.stock_location_id | The Stock Location id, only Spree >= 2.0 | 1 |

#### Response

---stock_change_response.json---

```json
{
  "message_id": "523c677763e2990205000007",
  "notifications": [
    {
      "level": "info",
      "subject": "stock:change",
      "description": "received 5 for sku APC-00001, changed stock from 0 to 5 (force = false)"
    }
  ],
  "sku": "APC-00001",
  "quantity": 5,
  "from": 0,
  "to": 5
}
```