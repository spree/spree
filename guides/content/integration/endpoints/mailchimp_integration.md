---
title: MailChimp Endpoint
---

## Overview

[MailChimp](http://www.mailchimp.com/) is an online email marketing solution to manage contacts, send emails and track results. 

+++
The source code for the [MailChimp Endpoint](https://github.com/spree/mailchimp_endpoint/) is available on Github.
+++

## Services

### Subscribe

Subscribe an e-mail to your MailChimp list

#### Request

### order:new

---order_new.json---
```json
{
  "message": "order:new",
  "payload": {
    "order": {
      "number": "R123456789",
      "email": "test1@test.com",
      "totals": {
        "item": 12.99,
        "adjustment": 10,
        "tax": 6,
        "shipping": 4,
        "payment": 29.99,
        "order": 29.99
      },
      "adjustments": [
      ],
      "line_items": [
      ],
      "shipping_address": {
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
      ],
      "shipments": [
      ]
    },
    "original": { .. }
  }
}
```

### order:updated

This type of message is generated when an existing order is updated.

---order_updated.json---
```json
{
  "message": "order:updated",
  "payload": {
    "order": {
      "email": "spree@example.com",
      "totals": {
        "item": 112.99,
        "adjustment": 10,
        "tax": 6,
        "shipping": 4,
        "order": 129.99
      },
      "adjustments": [
      ],
      "line_items": [
      ],
      "shipping_address": {
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
      ],
      "shipments": [
      ]
    },
    "original": { .. },
    "previous": {
      "number": "R123456789",
      "email": "test1@test.com",
      "status": "complete",
      "totals": {
        "item": 12.99,
        "adjustment": 10.0,
        "tax": 6.0,
        "shipping": 4.0,
        "payment": 29.99,
        "order": 29.99
      },
      "line_items": [ { } ],
      "adjustments": [ { } ],
      "shipping_address": { },
      "billing_address": { 
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
      "payments": [ { } ],
      "shipments": [ { } ]
    }
  }
}
```

#### Response

---notifications_info.json---

```json
{
  "notifications": [
    {
      "level": "info",
      "subject": "Successfully Subscribed spree@example.com To The MailChimp List",
      "description": "Successfully Subscribed spree@example.com To The MailChimp List"
    }
  ]
}
```

---notifications_error.json---

```json
{
  "notifications": [
    {
      "level": "error",
      "subject": "MailChimp Error Code 502",
      "description": "Invalid Email Address: spree@example.com",
      "backtrace": "..."
    }
  ]
}
```

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| mailchimp.api_key | Your MailChimp API key | dj20492dhjkdj20492dhjk |
| mailchimp.list_id | MailChimp List ID | dj20492dhjk |
