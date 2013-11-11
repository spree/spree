---
title: Messages
---

## Overview

The Spree Commerce hub API also allows messages to be pushed to it.

This guide covers how to see which message types can be pushed to the hub and instructions for pushing a message via the API.

## Available Messages


To see a list of message types you can push to the hub, make the following request:

```text
GET http://hub.spreecommerce.com/api/stores/YOUR_STORE_ID/available_messages```

The response will be a list of possible message types you can push. The following is an abbreviated list:

<%= headers 200 %>
<%= json \
    [
      "endpoint:poll",
      "notification:error",
      "notification:info",
      "notification:warn",
      "order:canceled",
      "order:import",
      "order:new",
      "order:persist",
      "order:updated",
      "payment:capture",
      "payment:ready",
      "product:update"
    ]
%>

## Pushing a Message to the Hub

***
For more information on the structure of messages and to view some sample messages, please view the [Sample Messages guide](/integration/sample_messages).
***

Let's go over pushing a couple different messages to the Spree Commerce hub. First, we'll push a more basic message, `stock:change`, and then we'll push a more complicated messages, `order:persist`.

### stock:change example

#### Request

To push a `stock:change` message, make the following request:

```text
post http://hub.spreecommerce.com/api/stores/your_store_id/messages```

with the following JSON request body:

<%= json \
    "message" => "stock:change",
    "payload" => {
      "sku" => "apc-00001",
      "quantity" => 10
    }
  %>

Here is an example request using cURL:

```curl
curl -XPOST -H"Content-Type: application/json" 
     -H"X-Augury-Token:YOUR_AUGURY_TOKEN" 
     -d '{"message":"stock:change","payload":{"sku":"APC-00001","quantity":10}' 
     http://hub.spreecommerce.com/api/stores/YOUR_STORE_ID/messages```

#### Response

<%= headers 201 %>
<%= json \
    "message"=> "stock:change",
    "payload"=> {
        "sku"=> "apc-00001",
        "quantity"=> 10
    },
    "message_id"=> "52811a8584a8169f7a000002"
%>

### order:persist example

#### Request

To push an `order:persist` message, make the following request:

```text
POST http://hub.spreecommerce.com/api/stores/YOUR_STORE_ID/messages```

with the following JSON request body:

<%= json \
    "message" => "order:persist",
    "payload" => {}
  %>

***
To view the details of what should be in an `order:persist` payload, use the samples API described in the [sample messages](/integration/sample_messages) guide to generate a sample message.
***

Here is an example request using cURL:

```curl
curl -XPOST -H"Content-Type: application/json" 
     -H"X-Augury-Token:YOUR_AUGURY_TOKEN" 
     -d '{"message":"order:persist","payload":{}' 
     http://hub.spreecommerce.com/api/stores/YOUR_STORE_ID/messages```

#### Response

<%= headers 201 %>
<%= json \
    "message"=> "order:persist",
    "payload"=> {},
    "message_id"=> "52811a8584a8169f7a000002"
%>
