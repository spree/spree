---
title: Queues
---

## Queue Stats

### Request

To get a count of the number of messages in each of your hub queues, make the 
following request:

```text
GET http://hub.spreecommerce.com/api/stores/YOUR_STORE_ID/queues```

### Response

<%= headers 200 %>
<%= json \
    "incoming"=> 2,
    "archived"=> 10000,
    "pending"=> 1,
    "failing"=> 5,
    "scheduled"=> 0,
    "parked"=> 0
 %>

## Incoming Queue

***
Note that the results returned are limited to 25 per page, you can specify which 
page to return by passing the `page` parameter in your request.
***

### Request

To view messages in the incoming queue, make the following request:

```text
POST http://hub.spreecommerce.com/api/stores/YOUR_STORE_ID/queues/incoming```

### Response

<%= headers 201 %>
<%= json(:incoming_queue) do |h|
[h]
end %>

## Accepted Queue

***
Note that the results returned are limited to 25 per page, you can specify which 
page to return by passing the `page` parameter in your request.
***

### Request

To view messages in the accepted queue, make the following request:

```text
POST http://hub.spreecommerce.com/api/stores/YOUR_STORE_ID/queues/accepted```

### Response

<%= headers 201 %>
<%= json(:accepted_queue) do |h|
[h]
end %>

## Archived Queue

***
Note that the results returned are limited to 25 per page, you can specify which 
page to return by passing the `page` parameter in your request.
***

### Request

To view messages in the archived queue, make the following request:

```text
POST http://hub.spreecommerce.com/api/stores/YOUR_STORE_ID/queues/archived```

***
By default, the above request will only return completed messages that are in 
the archived queue. To return messages that were not completed, set the `source` 
parameter when making the request.
***

### Response

<%= headers 201 %>
<%= json(:archived_queue) do |h|
[h]
end %>

## Filter Queues

It is possible to list messages in queues that only match certain filters.

You can filter queues by passing one or more of the following attributes as a 
parameter in the request:

* message - The message type to filter by, for example `order:persist`, 
`order:poll`, etc.

* state - The current state of the message. This can be completed, pending, 
failing, scheduled, never_processed, or parked.

* start_date

* end_date

* message_id - The id of the message

* mapping_id - The id of the mapping
