---
title: Integrations
---

## List Integrations

To get a list of integrations for your store, make the following request:

```text
GET http://hub.spreecommerce.com/api/stores/YOUR_STORE_ID/integrations```

### Response

<%= headers 200 %>
<%= json(:integration) do |h|
[h]
end %>
