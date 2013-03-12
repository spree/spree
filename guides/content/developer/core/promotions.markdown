---
  title: "Core | Models | Promotions"
---

## Overview

Promotions within Spree are used to provide discounts to orders, as well as
potential additional items at no extra cost. Promotions are *by far* the most
complex area within Spree, as there are a large number of moving parts to
consider.

The first of these moving parts is that promotions are based off
<%= link_to "Activators", :activators %>, using the functionality provided by
that area of Spree to know when to trigger the application of a promotion to an
order. **Please read that guide first**.

Promotions depend on activators to know when to activate. Promotions are only
activatable for an order if the order is in any state except "complete",
"awaiting return" or "returned".

Promotions relate to two other main components: actions and rules. When a
promotion is activated, the actions for the promotion are performed, passing in
the payload from the `fire_event` call that triggered the activator becoming
active. Rules are used to determine if a promotion meets certain criteria in
order to be applicable.

In some special cases where a promotion has a `code` or a `path` configured for
it, the promotion will only be activated if the payload's code or path match the
payload's. The `code` attribute is used for promotion codes, where a user must
enter a code to receive the promotion, and the `path` attribute is used to apply
a promotion once a user has visited a specific path.

!!!
Path-based promotions will only work if the `spree.content.visited` event is
triggered, with a call such as `fire_event('spree.content.visited')`. This is done
within `Spree::ContentController`, as an example.
!!!

A promotion may also have a `usage_limit` attribute set, which restricts how
many times the promotion can be used.

## Actions

There are two actions which come with Spree: one action to apply adjustments
(`Spree::Promotions::Actions::CreateAdjustment`),
and another to add a line item to an order
(`Spree::Promotion::Actions::CreateLineItem`).

### Creating an adjustment

When a `CreateAdjustment` action is undertaken, an adjustment is automatically
applied to the order, unless the promotion has already applied an adjustment to
the order.

Once the adjustment has been applied to the order, its eligibility is re-checked
every time the order is saved, by way of the
`Adjustment#eligible_for_originator?` method. This calls the `Promotion#eligible?`
method, which uses `Promotion#rules_are_eligible?` to determine if the promotion
is still eligible based on its rules. For how this process works, please see the
rules section further down in this guide.

An adjustment to an order from a promotion depends on the calculators. For more
information about calculators, please see the <%= link_to "Calculators guide",
:calculators %>

### Adding a line item

When a `LineItem` action is undertaken, a series of line items are automatically
added to the order, which may alter the order's price. The promotion with an
action to add a line item can also have another action to add an adjustment to
the order to nullify the cost of adding the product to the order.

### Registering a new action

You can create a new action for Spree's promotion engine by inherting from
`Spree::PromotionAction`, like this:

```ruby
class MyPromotionAction < Spree::PromotionAction
  def perform(options={})
  end
end
```

***
You can access promotion information using the `promotion` method within any
`Spree::PromotionAction`.
***

This action must then be registered with Spree, which can be done by adding this
code to `config/initializers/spree.rb`:

    Rails.application.config.spree.promotion.actions << MyAction

Once this has been registered, it will be available within Spree's interface. To
provide translations for the interface, you will need to define them within your
locale file. For instance, to define English translations for your new promotion
action, use this code within `config/locales/en.yml`:

en:
  spree:
    promotion_action_types:
      my_promotion_action:
        name: My Promotion Action
        description: Performs my promotion action.

## Rules

There are five rules which come with Spree:

* `FirstOrder`: The user's order is their first.
* `ItemTotal`: The order's total is greater than (or equal to) a given value.
* `Product`: An order contains a specific product.
* `User` The order is by a specific user.
* `UserLoggedIn`: The user is logged in.

Rules are used by Spree to determine if a promotion is applicable to an order
and can be matched in one of two ways: all the rules must match, or one rule
must match. This is determined by the `match_policy` attribute on the
`Promotion` object.

### Registering a new rule

To register a new rule with Spree, first define a class that inherits from
`Spree::PromotionRule`, like this:

    class MyPromotionRule < Spree::PromotionRule
      def eligible?(order)
      end
    end

The `eligible?` method should then return `true` or `false` to indicate if the
promotion should be eligible for an order. You can retreive promotion
information by calling `promotion`.

Then register it using this code inside `config/initializers/spree.rb`:

     Rails.application.config.spree.promotion.rules << MyPromotionRule

Once this rule has been registered, it will be available within Spree's
interface.

