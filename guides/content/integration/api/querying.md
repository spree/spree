---
title: Querying
---

## List Integrations

### Request

To get a list of integrations for your store, make the following request:

```text
GET http://hub.spreecommerce.com/api/stores/YOUR_STORE_ID/integrations```

### Response

<%= headers 200 %>
<%= json(:integration) do |h|
[h]
end %>

## Create An Integration

### Request

To create a new integration through the API, make the following request:

```text
POST http://hub.spreecommerce.com/api/stores/YOUR_STORE_ID/integrations```

Here is an example of the parameters you are required to send along with this request
in order to create a new integration:

<%= json \
  :integration => {
    :name     => "custom_endpoint",
    :url      => "http://custom-endpoint.com",
    :category => "custom"
  } %>

or you can pass the parameters through in the URL string as follows:

```text
POST http://hub.spreecommerce.com/api/stores/YOUR_STORE_ID/integrations?
     integration[name]=custom_endpoint&integration[category]=custom&
     integration[url]=http://custom-endpoint.com```

***
While the category is required, it can be set to anything you want. This is
only used for your reference.
***

### Response

<%= headers 201 %>
<%= json \
    "id" => "527a68b384a816fb91000001",
    "name" => "custom_endpoint",
    "display" => nil,
    "description" => nil,
    "help" => nil,
    "url" => "http://custom-endpoint.com",
    "category" => "custom",
    "error_messages" => nil,
    "icon_url" => nil,
    "store_id" => "YOUR_STORE_ID"
  %>
