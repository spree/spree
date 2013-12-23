---
title: Amazon Simple Email Service (SES) Endpoint
---

## Overview

[Amazon Simple Email Service](aws.amazon.com/ses/‎) is part of Amazon.com's cloud computing platform, Amazon Web Services. SES provides AWS users with infrastructure for sending outbound bulk email correspondence.

+++
The source code for the [Amazon SES Endpoint](https://github.com/spree/amazon_ses_endpoint/) is available on Github.
+++

## Services

### Send E-mail

Send e-mail information to Amazon Simple Email Service.

#### Request

### email:send

---send_email.json---
```json
{
   "message": "email:send",
   "payload": {
      "email": {
         "subject": "Hello World Subject",
         "body": {
            "text": "Hello World body",
            "html": "<h1>Hello World Body</h1>"
         },
         "to": "test@gmail.com",
         "from": "test@gmail.com",
         "cc": "test@gmail.com,test2@gmail.com",
         "bcc": "test3@gmail.com"
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
      "subject": "Successfully sent an email to test@gmail.com, test2@gmail.com via the Amazon Simple Email Service",
      "description": "Successfully sent an email to test@gmail.com, test2@gmail.com via the Amazon Simple Email Service"
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
      "subject": "InvalidArguments: 'to', 'from', 'subject', 'body' attributes are required",
      "description": "...",
      "backtrace": "..."
    }
  ]
}
```

#### Parameters

| Name | Value | Data Type | Required? |Example |
| :----| :-----| :------ |:------ | :------ |
| amazon_ses.access_key_id | Your AWS Access Key ID | string | Yes | dj20492dhjkdj20492dhjk |
| amazon_ses.secret_access_key | Your AWS Secret Access Key | string | Yes | dj20492dhjkdj20492dhjk |
