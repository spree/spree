---
title: Notifications
---

## List Notifications

### Request

To get a list of notifications for your store, make the following request:

```text
GET http://hub.spreecommerce.com/api/stores/YOUR_STORE_ID/notifications```

### Response

<%= headers 200 %>
<%= json(:notification) do |h|
[h]
end %>

## Querying Notifications

It is possible to list notifications that only match certain filters.

You can filter notifications by passing one or more of the following attributes as a parameter in the request:

* reference_type
* reference_token
* level

### Request

As an example, let's list notifications that have a level of error. This can be done with a request similar to the following:

```text
GET http://hub.spreecommerce.com/api/stores/YOUR_STORE_ID/notifications?level=error```

### Response

<%= headers 200 %>
<%= json(:error_notification) do |h|
[h]
end %>
