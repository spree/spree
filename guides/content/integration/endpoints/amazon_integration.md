---
title: Amazon Endpoint
---

## Overview

Amazon is... This endpoint can be used for...

* ,
* , or
* .

## Requirements

In order to configure and use the [amazon_endpoint](https://github.com/spree/amazon_endpoint), you will need to first have:

* ,
* , and
*

## Services

There are Message types that the Endpoint can respond to (incoming), and those that it can, in turn, generate (outgoing). A Service Request is the sequence of actions the Endpoint takes when the Integrator sends it a Message. There are several types of Service Requests you can make to the Endpoint. Each is listed below, along with one or more sample JSON Messages like the ones you would send.

***
To see thorough detail on how a particular JSON Message should be formatted, check out the [Notification Messages guide](notification_messages).
***

### abc

This Service should be triggered {when}. When the Endpoint receives a validly-formatted Message to the `/{abc}` URL, it {takes some actions}.

<pre class="headers"><code>Event</code></pre>
```json
{
  "message": "order:new",
  "payload": {
    ...
  }
}```

### abc

This Service should be triggered {when}. When the Endpoint receives a validly-formatted Message to the `/{abc}` URL, it {takes some actions}.

<pre class="headers"><code>Event</code></pre>
```json
{
  "message": "order:new",
  "payload": {
    ...
  }
}```

### abc

This Service should be triggered {when}. When the Endpoint receives a validly-formatted Message to the `/{abc}` URL, it {takes some actions}.

<pre class="headers"><code>Event</code></pre>
```json
{
  "message": "order:new",
  "payload": {
    ...
  }
}```

## Configuration

TODO: Elaborate when we finalize the connector.

### Name

### Keys

#### {abc}

#### {from}

#### {subject}

#### {template}

### Parameters

### Url

### Token

### Event Keys

### Event Details

### Filters

### Retries