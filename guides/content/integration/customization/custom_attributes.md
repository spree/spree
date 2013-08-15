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

end```

You name this file `api_helpers_decorator.rb` and store it in your application's `/app/helpers/spree/api` directory.
