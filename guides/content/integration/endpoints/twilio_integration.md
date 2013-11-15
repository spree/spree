---
title: Twilio Integration
---

## Overview

[Twilio](http://www.twilio.com/) lets you send customers SMS every time an order
is received or a shipment goes out. 

+++
The source code for the [Twilio Integration](https://github.com/spree/twilio_endpoint/) is available on Github.
+++

## Services

### SMS Order

Sends a SMS for every new order.

### SMS Ship

Sends a SMS every time a shipment ships.

#### Parameters

Both services need the same parameters

| Name | Value | Example |
| :----| :-----| :------ |
| twilio.account_sid | The SID value provided by Twilio on your account | regw45432542ragregewrgewrg4r |
| twilio.auth_token | The Auth token provided by Twilio on your account | 234534regegrewgwergergwegeg |
| twilio.phone_from | The phone number provided by Twilio on your account | 315 4566 3455 |
| twilio.address_type | Specify which address should phone number be picked from | billing |

#### Response

```json
{
  "message_id": "518726r84910515003",
  "notifications": [
    "level": "info",
    "subject": "SMS confirmation sent to +55 86 8869 9999",
    "description": "Hey Bob! Your order R4534543535 has been received."
  ]
}
```
