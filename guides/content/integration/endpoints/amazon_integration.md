---
title: Amazon Endpoint
---

## Overview

[Amazon](http://www.amazon.com/) is one of the Internet's largest retailers. This endpoint can be used to poll the Amazon API and import any new orders you may have there into your Spree store.

## Requirements

In order to configure and use the [amazon_endpoint](https://github.com/spree/amazon_endpoint), you will need to first have an Amazon seller account, which provides you with your:

* Amazon AWS access key,
* Amazon secret key,
* Amazon seller ID, and
* Amazon `marketplace_id`.

You'll also need to set a `last_created_after` date to give the Endpoint a date range against which to compare.

## Services

***
To see thorough detail on how a particular JSON Message should be formatted, check out the [Notification Messages guide](notification_messages).
***

### Return Orders

When the Endpoint receives a validly-formatted Message to the `/get_orders` URL, it returns all new orders created in the Amazon store since the `last_created_after` date.

<pre class="headers"><code>Retrieve new orders</code></pre>
```json
{
  "message": "amazon:order:poll",
  "message_id": "1234567"
}```

## Configuration

$$$
Elaborate when we finalize the connector.
$$$

### Name

### Keys

### Parameters

#### amazon.marketplace_id

#### amazon.seller_id

#### amazon.last_created_after

#### amazon.aws_access_key

#### amazon.secret_key

### Url

### Token

### Event Keys

### Event Details

### Filters

### Retries