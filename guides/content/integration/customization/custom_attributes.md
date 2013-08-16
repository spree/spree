---
title: Custom Attributes
---

## Introduction

As a user of both Spree and the Spree Integrator, it's important to keep customizations you've made to your Spree store in synch with the mappings you have on the Integrator. This guide instructs you on using decorators to add any custom fields you've added to your store's Order, Product, and Variant objects to the JSON output that is sent to the Integrator.

## Native JSON Output

You can see the list of fields that are exported by default by looking at the [Spree::Api::ApiHelpers class](https://github.com/spree/spree/blob/master/api/app/helpers/spree/api/api_helpers.rb). For example, you can see that within the `line_item_attributes` array, the `id`, `quantity`, `price`, and `variant_id` keys are passed, along with their values.

To extend this out-of-the-box functionality, you need to decorate this ApiHelpers class within your project. This allows you to add fields to suit the needs of your business.

## Extending the JSON Output

Let's assume you need to add a `upc` field to your products' variants. Your decorator would look like this:

```ruby
Spree::Api::ApiHelpers.class_eval do
  def variant_attributes_with_upc
    variant_attributes_without_upc << :upc
  end

  alias_method_chain :variant_attributes, :upc
end
```

You name this file `api_helpers_decorator.rb` and store it in your application's `/app/helpers/spree/api` directory.

Then, when your store's orders are output, you'll see the custom `upc` field in the JSON file (much of the output is omitted below for brevity).

```json
{
  "message": "order:new",
  "payload": {
    "orders": [ {
      "id": 12345,
      "number": "R123456789",
      "line_items": [ {
        "id": 54321,
        "variant": {
          "id": 67890,
          "name": "Ruby on Rails Tote",
          "upc": "ABC123" }
      } ]
    } ]
  }
}
```

## Messages From the Integrator

Messages that come from the Integrator will not have the custom fields encoded like the ones exported from Spree. The Integrator's messages use the standard [order message format](order_messages), but the custom fields will be accessible through the `original` key within the `payload`.

```json
{
  "message": "order:new",
  "payload": {
    "orders": [ {
      "current": {
        "id": 12345,
        "number": "R123456789",
        "line_items": [ {
          "id": 54321,
          "variant": {
            "id": 67890,
            "name": "Ruby on Rails Tote" }
        } ]
      },
      "original": {
        "id": 12345,
        "number": "R123456789",
        "line_items": [ {
          "id": 54321,
          "variant": {
            "id": 67890,
            "name": "Ruby on Rails Tote",
            "upc": "ABC123" }
        } ]
      }
    } ]
  }
}```
