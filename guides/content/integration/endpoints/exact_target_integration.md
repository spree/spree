---
title: ExactTarget Endpoint
---

## Overview

[ExactTarget](http://www.exacttarget.com/) is an email marketing and interactive marketing provider.

+++
The source code for the [ExactTarget Endpoint](https://github.com/spree/exact_target_endpoint/) is available on Github.
+++

## Services

### Send E-mail

Send [Triggered E-mail](http://help.exacttarget.com/en-GB/documentation/exacttarget/interactions/triggered_emails/triggered_emails_guide/) to ExactTarget.

#### Request

Preprocessors could be used to modify the payload to include the "email" hash that the endpoint is expecting. All of the [data extension fields](http://help.exacttarget.com/en/documentation/exacttarget/subscribers/data_extensions_and_data_relationships/) that have been configured through the ExactTarget application must be passed in under the "parameters" hash.

### order:new

---send_email.json---
```json
{
   "message": "order:new",
   "payload": {
      "email": {
         "to": "test@gmail.com",
         "template": "sample",
         "parameters": {
          "Subject": "Order Confirmation",
          "Last_Name": "Bondarev",
          "Order_Number": "R927560531",
          "Order_Date": "2013-07-30T19:19:05.000Z",
          "Ship_To_Address": "Bethesda, Maryland, US, 20814",
          "Bill_To_Address": "Bethesda, Maryland, US, 20814"
         }
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
      "subject": "Successfully enqued an email to test@gmail.com via ExactTarget",
      "description": "Successfully enqued an email to test@gmail.com via ExactTarget"
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
      "subject": "'to', 'template', 'parameters' attributes are required",
      "description": "...",
      "backtrace": "..."
    }
  ]
}
```

#### Parameters

| Name | Value | Data Type | Required? |Example |
| :----| :-----| :------ |:------ | :------ |
| exact_target.username | Your ExactTarget Username | string | Yes | user123 |
| exact_target.password | Your ExactTarget Password | string | Yes | password123 |
| exact_target.api_url | Your ExactTarget API URL | string | No | webservice.s6.exacttarget.com |
