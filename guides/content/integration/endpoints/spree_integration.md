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
  "consumer_class": "Augury::Consumers::Remote",
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

```json
{
  "message": "order:ship",
  "payload": {
    "parameters": [
      {
        "name": "access_token",
        "value": "eac97693-26be-11e3-9a20-856fcdde1271"
      },
      {
        "name": "refresh_token",
        "value": "eac6b772-26be-11e3-9a20-856fcdde1271"
      }
    ],
    "order": {
      "number": "R123456789",
      "channel": "Amazon",
      "email": "test1@test.com",
      "currency": "USD",
      "placed_on": "2013-09-20T16:24:22-04:00",
      "updated_at": "2013-09-20T16:24:22-04:00",
      "status": "complete",
      "totals": {
        "item": 12.99,
        "adjustment": 10,
        "tax": 6,
        "shipping": 4,
        "payment": 29.99,
        "order": 29.99
      },
      "adjustments": [
        {
          "name": "Shipping Discount",
          "value": "-4.99"
        },
        {
          "name": "Promotion Discount",
          "value": "-3.00"
        }
      ],
      "line_items": [
        {
          "name": "Foo T-Shirt Size(L)",
          "sku": "ABC-123",
          "external_ref": "ABD-123",
          "quantity": 1,
          "price": 19.99,
          "options": {
            "color": "BLK", 
            "size": "XL" 
          }
        },
        {
          "name": "Foo Shoe",
          "sku": "DEF-123",
          "external_ref": "DDD-123",
          "quantity": 3,
          "price": 23.99,
          "options": {
            "color": "BLK", 
            "size": "XL" 
          }
        }
      ],
      "shipping_address": {
        "firstname": "Chris",
        "lastname": "Mar",
        "address1": "112 Hula Lane",
        "address2": "",
        "city": "Leesburg",
        "zipcode": "20175",
        "phone": "555-555-1212",
        "country": "US",
        "state": "Virginia"
      },
      "billing_address": {
        "firstname": "Chris",
        "lastname": "Mar",
        "address1": "112 Billing Lane",
        "address2": "",
        "city": "Leesburg",
        "zipcode": "20175",
        "phone": "555-555-1212",
        "country": "US",
        "state": "Viriginia"
      },
      "payments": [
        {
          "number": 1234,
          "status": "completed",
          "amount": 29.99,
          "payment_method": "Standard"
        }
      ],
      "shipments": [
        {
          "number": "1234567",
          "cost": 29.99,
          "status": "ready",
          "stock_location": "PCH",
          "shipping_method": "UPS Next Day",
          "tracking": null,
          "updated_at": null,
          "shipped_at": null,
          "items": [
            {
              "name": "Foo T-Shirt Size(L)",
              "sku": "ABC-123",
              "external_ref": "ABD-123",
              "quantity": 1,
              "price": 19.99,              
              "variant_id": 123,
              "options": {
                "color": "BLK", 
                "size": "XL" 
              }
            },
            {
              "name": "Foo Socks",
              "sku": "DEF-123",
              "external_ref": "DDD-123",
              "quantity": 3,
              "price": 23.99, 
              "variant_id": 789,             
              "options": {
                "color": "BLK", 
                "size": "XL" 
              }
            }
          ]
        }
      ]
    },
    "original": {
      "id": 900000,
      "number": "R123456789",
      "promotion": "123",
      "campaign": "456",
      "item_total": "12.99",
      "total": "29.99",
      "state": "complete",
      "adjustment_total": "10.00",
      "user_id": 8567,
      "created_at": "2013-09-20T16:24:22-04:00",
      "updated_at": "2013-09-20T16:24:22-04:00",
      "completed_at": "2013-09-20T16:24:22-04:00",
      "payment_total": "29.99",
      "shipment_state": "ready",
      "payment_state": "paid",
      "email": "test1@test.com",
      "special_instructions": null,
      "currency": "USD",
      "ship_total": "4.00",
      "tax_total": "6.00",
      "bill_address": { 
        "firstname": "Chris",
        "lastname": "Mar",
        "address1": "112 Hula Lane",
        "address2": "",
        "city": "Leesburg",
        "zipcode": "20175",
        "phone": "555-555-1212",
        "country": {
          "name": "US"
        },
        "state": {
          "abbr": "VA",
          "name": "Virginia"
        }
      },
      "ship_address": { },
      "line_items": [ { } ],
      "payments": [ { } ],
      "shipments": [ { } ],
      "adjustments": [ { } ],
      "credit_cards": [ { } ],
      "store_id": { "$oid": "62n8eaa2b4381934bc000001" },
      "next_id": null,
      "_id": "123poi67q98712304658mq8r"
    }
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

```
{
   "message_id"   =>"52053091fe53545249000eee",
   "locked"   =>   {
      "number"      =>"R514128512",
      "locked_at"      =>"2013-08-09T20:10:33      Z"
   }
}
```

### Order Import

When sent an "order:import" message to '/orders/import', the endpoint imports an order into the Spree store.

####Request

```
{
  "store_name": "ABC Widgets",
  "message": "order:import",
  "consumer_class": "Augury::Consumers::Remote",
  "mapping": {
    "enabled": true,
    "filters": [
      {
        "path": "payload.order.channel",
        "operator": "eq",
        "value": "Amazon.com"
      }
    ],
    "identifiers": {
      "order_number": "payload.order.number"
    },
    "messages": [
      "order:import"
    ],
    "name": "spree.order.new",
    "options": {
      "retries_allowed": true
    },
    "parameters": [ ],
    "required": false,
    "token": "123",
    "url": "http://ep-spree1.spree.fm/orders/import",
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
| truncate_address_address1 | Maximum Length of Address1 Field | 255 |

#### Response

```
{
  "code": "200",
  "response": {
    "message_id": "523fcd00b439573338018fab",
    "notifications": [
      {
        "level": "warn",
        "subject": "address1 was truncated",
        "description": "address1 was truncated from '2000 Grande Canyon Boulevard, No 3523' to '2000 Grande Canyon Boulev'"
      }
    ],
    "order": {
      ...
    }
  }
}
```

### Payments Capture

When sent an "order:capture" message to '/payments/capturer', the endpoint captures the payment on an order.

####Request

```
{
  "message": "order:capture",
  "payload": {
    "parameters": [
      {
        "name": "access_token",
        "value": "eac97693-26be-11e3-9a20-856fcdde1271"
      },
      {
        "name": "refresh_token",
        "value": "eac6b772-26be-11e3-9a20-856fcdde1271"
      }
    ],
    "order": {
      "number": "R123456789",
      "channel": "Amazon",
      "email": "test1@test.com",
      "currency": "USD",
      "placed_on": "2013-09-20T16:24:22-04:00",
      "updated_at": "2013-09-20T16:24:22-04:00",
      "status": "complete",
      "totals": {
        "item": 12.99,
        "adjustment": 10,
        "tax": 6,
        "shipping": 4,
        "payment": 29.99,
        "order": 29.99
      },
      "adjustments": [
        {
          "name": "Shipping Discount",
          "value": "-4.99"
        },
        {
          "name": "Promotion Discount",
          "value": "-3.00"
        }
      ],
      "line_items": [
        {
          "name": "Foo T-Shirt Size(L)",
          "sku": "ABC-123",
          "external_ref": "ABD-123",
          "quantity": 1,
          "price": 19.99,
          "options": {
            "color": "BLK", 
            "size": "XL" 
          }
        },
        {
          "name": "Foo Shoe",
          "sku": "DEF-123",
          "external_ref": "DDD-123",
          "quantity": 3,
          "price": 23.99,
          "options": {
            "color": "BLK", 
            "size": "XL" 
          }
        }
      ],
      "shipping_address": {
        "firstname": "Chris",
        "lastname": "Mar",
        "address1": "112 Hula Lane",
        "address2": "",
        "city": "Leesburg",
        "zipcode": "20175",
        "phone": "555-555-1212",
        "country": "US",
        "state": "Virginia"
      },
      "billing_address": {
        "firstname": "Chris",
        "lastname": "Mar",
        "address1": "112 Billing Lane",
        "address2": "",
        "city": "Leesburg",
        "zipcode": "20175",
        "phone": "555-555-1212",
        "country": "US",
        "state": "Viriginia"
      },
      "payments": [
        {
          "number": 1234,
          "status": "completed",
          "amount": 29.99,
          "payment_method": "Standard"
        }
      ],
      "shipments": [
        {
          "number": "1234567",
          "cost": 29.99,
          "status": "ready",
          "stock_location": "PCH",
          "shipping_method": "UPS Next Day",
          "tracking": null,
          "updated_at": null,
          "shipped_at": null,
          "items": [
            {
              "name": "Foo T-Shirt Size(L)",
              "sku": "ABC-123",
              "external_ref": "ABD-123",
              "quantity": 1,
              "price": 19.99,              
              "variant_id": 123,
              "options": {
                "color": "BLK", 
                "size": "XL" 
              }
            },
            {
              "name": "Foo Socks",
              "sku": "DEF-123",
              "external_ref": "DDD-123",
              "quantity": 3,
              "price": 23.99, 
              "variant_id": 789,             
              "options": {
                "color": "BLK", 
                "size": "XL" 
              }
            }
          ]
        }
      ]
    },
    "original": {
      "id": 900000,
      "number": "R123456789",
      "promotion": "123",
      "campaign": "456",
      "item_total": "12.99",
      "total": "29.99",
      "state": "complete",
      "adjustment_total": "10.00",
      "user_id": 8567,
      "created_at": "2013-09-20T16:24:22-04:00",
      "updated_at": "2013-09-20T16:24:22-04:00",
      "completed_at": "2013-09-20T16:24:22-04:00",
      "payment_total": "29.99",
      "shipment_state": "ready",
      "payment_state": "paid",
      "email": "test1@test.com",
      "special_instructions": null,
      "currency": "USD",
      "ship_total": "4.00",
      "tax_total": "6.00",
      "bill_address": { 
        "firstname": "Chris",
        "lastname": "Mar",
        "address1": "112 Hula Lane",
        "address2": "",
        "city": "Leesburg",
        "zipcode": "20175",
        "phone": "555-555-1212",
        "country": {
          "name": "US"
        },
        "state": {
          "abbr": "VA",
          "name": "Virginia"
        }
      },
      "ship_address": { },
      "line_items": [ { } ],
      "payments": [ { } ],
      "shipments": [ { } ],
      "adjustments": [ { } ],
      "credit_cards": [ { } ],
      "store_id": { "$oid": "62n8eaa2b4381934bc000001" },
      "next_id": null,
      "_id": "123poi67q98712304658mq8r"
    }
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

```
{
   "code"   =>"200",
   "response"   =>   {
      "message_id"      =>"523f99asdfbasdf6be007808",
      "payment"      =>      {
         "id"         =>20437,
         "source_type"         =>"Spree::CreditCard",
         "source_id"         =>1,
         "amount"         =>"264.73",
         "payment_method_id"         =>1,
         "response_code"         =>"507544062",
         "state"         =>"completed",
         "avs_response"         =>"Y",
         "created_at"         =>"2013-09-23T01:28:19         Z",
         "updated_at"         =>"2013-09-23T01:30:42         Z"
      },
      "messages"      =>      [
         {
            "message"            =>"order:            payment:captured",
            "payload"            =>            {
               "order_id"               =>"523f99b2fe53546fc504815d",
               "payment_id"               =>1
            }
         }
      ]
   }
}
```

### Inventory Unit Service

When sent an "shipment:confirm" message to /shipments/inventory_unit, the endpoint logs serial numbers on an inventory unit based on the external_ref provided.

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

```
{
   "code"   =>"200",
   "response"   =>   {
      "message_id"      =>"523f99bcfe535466be007808",
      "payment"      =>      {
         "id"         =>20437,
         "source_type"         =>"Spree::CreditCard",
         "source_id"         =>16122,
         "amount"         =>"264.73",
         "payment_method_id"         =>931422127,
         "response_code" => "507544062",
         "state"         =>"completed",
         "created_at" => "2013-09-23T01:28:19 Z",
         "updated_at" => "2013-09-23T01:30:42 Z"
      },
      "messages" => [
         {
            "message"            =>"order:payment:captured",
            "payload" => {
               "order_id" => "523f99b2fe53546fc504815d",
               "payment_id" => 20437
            }
         }
      ]
   }
}
```

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