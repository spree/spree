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

```
{
  "code": "200",
  "response": {
    "message_id": "5245b538b4395707ef0036f5",
    "parameters": [
      {
        "name": "spree.order_poll.last_updated_at",
        "value": "2013-09-27T15:57:28Z"
      }
    ],
    "messages": [
      ...
    ]
  }
}
```
### Order Lock

When sent an "order:ship" message to '/orders/lock', the endpoint Locks the order in a Spree store, preventing the admin from editing it.


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

When sent an "stock:change" message to '/stock/change', the endpoint updates the count on hand for a product in a Spree store.


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

When sent an "order:import" message to '/orders/import', the endpoint imports an order into the Spree store.


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

When sent an "order:capture" message to '/payments/capturer', the endpoint captures the payment on an order.

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

When sent an "shipment:confirm" message to /shipments/inventory_unit, the endpoint logs serial numbers on an inventory unit based on the external_ref provided.

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

When sent an "shipment:confirm" message to '/stock/transfer_poller', the endpoint marks a shipment as shipped, and adds tracking details.

####Request

```json
{
  "message": "shipment:confirm",
  "message_id": "518726r84910000004",
  "payload": {
    "shipment_number": 1,
    "tracking_number": "123456",
    "tracking_url": "http://www.ups.com/WebTracking/track",
    "carrier": "UPS",
    "shipped_date": "2013-06-27T13:29:46Z",
    ...
  }
}
```

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

```
{
  "store_name": "ABC Widgets",
  "message": "spree:stock_transfer:poll",
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
      "spree:stock_transfer:poll"
    ],
    "name": "spree.stock_transfer.poll",
    "options": {
      "retries_allowed": true
    },
    "parameters": [ ],
    "required": true,
    "store_id": {
      "$oid": "123"
    },
    "token": "abc123",
    "url": "http://ep-spree.spree.fm/stock/transfer_poller",
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
| stock_transfer_poller.last_updated_at | Import all stock transfers after this timestamp | 2013-09-24T19:50:00Z |

#### Response

```
{
  "code": "200",
  "response": {
    "message_id": "51da39193ed6f0235700000a",
    "parameters": [
      {
        "name": "spree.stock_transfer_poller.last_updated_at",
        "value": "2013-07-09T16:20:05+00:00"
      }
    ],
    "messages": [
      {
        "key": "stock_transfer:persist",
        "payload": {
          "id": 1,
          "created_at": "2013-07-09T16:20:05Z",
          "updated_at": "2013-07-09T16:20:05Z",
          "source_location": {
            "id": 1,
            "address1": null,
            "address2": null,
            "city": null,
            "zipcode": null,
            "phone": null,
            "country_id": 41,
            "state_id": null,
            "state_name": null,
            "country": {
              "id": 41,
              "iso_name": "CHINA",
              "iso": "CN",
              "iso3": "CHN",
              "name": "China",
              "numcode": 156
            },
            "": null,
            "name": "Default"
          },
          "source_movements": [
            {
              "id": 1176,
              "quantity": -13,
              "stock_item_id": 3,
              "stock_item": {
                "id": 3,
                "count_on_hand": 541,
                "backorderable": true,
                "stock_location_id": 1,
                "variant_id": 3,
                "variant": {
                  "id": 3,
                  "name": "bobblehead",
                  "product_id": 3,
                  "external_ref": "Bobblehead1",
                  "sku": "Bobblehead1",
                  "price": "30.0",
                  "weight": "3.000",
                  "height": "10.0",
                  "width": "34.0",
                  "depth": "12.0",
                  "is_master": true,
                  "cost_price": null,
                  "permalink": "bobblehead"
                }
              }
            }
          ],
          "destination_location": {
            "id": 3,
            "address1": null,
            "address2": null,
            "city": null,
            "zipcode": null,
            "phone": null,
            "country_id": 214,
            "state_id": null,
            "state_name": null,
            "country": {
              "id": 214,
              "iso_name": "UNITED STATES",
              "iso": "US",
              "iso3": "USA",
              "name": "United States",
              "numcode": 840
            },
            "": null,
            "name": "office"
          }
        }
      }
    ],
    "response": {
    }
  }
}
```

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