---
title: "Checkout"
section: customization
order: 5
---

## Overview

The Spree checkout process has been designed for maximum flexibility. It's been redesigned several times now, each iteration has benefited from the feedback of real world deployment experience. It is relatively simple to customize the checkout process to suit your needs. Secure transmission of customer information is possible via SSL and credit card information is never stored in the database.

The customization of the flow of the checkout can be done by using Spree's `checkout_flow` DSL, described in the [Checkout Flow DSL](#the-checkout-flow-dsl) section below.

## Default Checkout Steps

The Spree checkout process consists of the following steps. With the exception of the Registration step, each of these steps corresponds to a state of the `Spree::Order` object:

1. Registration (optional)
  
    Only when Spree Auth Devise is installed and `Spree::Auth::Config[:registration_step]` is set to `true`. Default is `true`.

2. Address Information
3. Delivery Options (Shipping Method)
4. Payment
5. Confirmation (optional)

    Optional - only if `Spree::Config[:always_include_confirm_step]` is set to `true`. Default is `false`.

6. Complete

The following sections will provide a walk-though of a checkout from a user's perspective, and offer some information on how to configure the default behavior of the various steps.

### Registration

Prior to beginning the checkout process, the customer will be prompted to create a new account or to login to their existing account.

By default, there is also a **guest checkout** option which allows users to specify only their email address if they do not wish to create an account.

To turn off guest checkout set `Spree::Config[:allow_guest_checkout]` to `false`. Default is `true`.

Technically, the registration step is not an actual state in the `Spree::Order` state machine. The `spree_auth_devise` gem (an extension that comes with Spree by default) adds the `check_registration` before action to the all actions of `Spree::CheckoutController` which redirects to a registration page unless one of the following is true:

* `Spree::Auth::Config[:registration_step]` preference is `false`
* user is already signed in

### Address Information

This step allows the customer to add both their billing and shipping information. Customers can click the "use billing address" option to use the same address for both.

There are several Configuration options for Address form:

* `Spree::Config[:address_fields]`

  List of fields that are going to be displayed on the address form. **This is only available in Spree 4.2 or newer**

  Default value:

  ```ruby
  %w(label firstname lastname company address1 address2 city state zipcode country phone alternative_phone)
  ```

* `Spree::Config[:address_requires_state]`

  Disables / enables state requirement (validation)

  Default value: `true`

* `Spree::Config[:address_requires_phone]`

  Disables / enables phone requirement (validation)

  Default value: `true`

#### Adding new field to Address form

1. Create column / attribute via Rails migration, eg.

    ```bash
    rails g migration AddNewFieldToSpreeAddresses new_field:string
    rails db:migrate
    ```

2. In `config/initializers/spree.rb`

    ```ruby
    Spree::Config[:address_fields] = %w(label firstname lastname company address1 address2 city state zipcode country phone new_field)
    ```

### Delivery Options

During this step, the user may choose a delivery method. Spree assumes the list of shipping methods to be dependent on the shipping address. Which shipping methods are available for which address are dependant on [Zones configuration](/developer/core/addresses.html#zones).

### Payment

This step is where the customer provides payment information. This step is intentionally placed last in order to minimize security issues.

Which Payment Methods are made available is determined which Payment Method is [set to be visible and associated with the current Store](/developer/core/payments.html#payment-methods).

For Credit Card-based payments Spree stores only the last four digits of the credit card number along with the expiration information. The full credit card number and verification code are never stored in the Spree database.

Some Payments Gateways such as Stripe or Braintree support [Strong customer authentication](https://en.wikipedia.org/wiki/Strong_customer_authentication) aka 3D Secure 2.0. This will add an additional Checkout Step where the User will need to verify their payment.

For more information about payments, please see the [Payments guide](/developer/core/payments.html).

### Confirmation

This is the final opportunity for the customer to review their order before
submitting it to be processed. Users have the opportunity to return to any step in the process and modify their information.

This step is disabled by default but can be enabled for all Orders via [Preferences](/developer/core/preferences.html) in `config/initializers/spree.rb`:

```ruby
Spree::Config[:always_include_confirm_step] = true
```

## Checkout Architecture

The following is a detailed summary of the checkout architecture. A complete
understanding of this architecture will allow you to be able to customize the
checkout process to handle just about any scenario you can think of. Feel free
to skip this section and come back to it later if you require a deeper
understanding of the design in order to customize your checkout.

### The Order Model and State Machine

 The `Spree::Order` state machine is the foundation of the checkout process. Spree makes use of the [state_machines](https://github.com/state-machines/state_machines) gem in the `Spree::Order` model as well as in several other places (such as `Spree::Shipment` and `Spree::InventoryUnit`.)

The default checkout flow for the `Spree::Order` model is defined in
`app/models/spree/order/checkout.rb` of `spree_core`.

An `Spree::Order` object has an initial state of 'cart'. From there any number
of events transition the `Spree::Order` to different states. Spree does not
have a separate model or database table for the shopping cart. What the user
considers a "shopping cart" is actually an in-progress `Spree::Order`. An order
is considered in-progress, or incomplete when its `completed_at` attribute is
`nil`. Incomplete orders can be easily filtered during reporting and it's also
simple enough to write a quick script to periodically purge incomplete orders
from the system. The end result is a simplified data model along with the
ability for store owners to search and report on incomplete/abandoned orders.

<alert kind="note">
  For more information on the state machines gem please see the [README](https://github.com/state-machines/state_machines)
</alert>

### The Checkout Flow DSL

Spree comes with a checkout DSL that allows you succinctly define the
different steps of your checkout. This DSL allows you to customize *just*
the checkout flow, while maintaining the unrelated admin states, such as
"canceled" and "resumed", that an order can transition to.

The default checkout flow for Spree is defined like this, adequately
demonstrating the abilities of this new system:

```ruby
checkout_flow do
  go_to_state :address
  go_to_state :delivery
  go_to_state :payment, if: ->(order) {
    order.update_totals
    order.payment_required?
  }
  go_to_state :confirm, if: ->(order) { order.confirmation_required? }
  go_to_state :complete
  remove_transition from: :delivery, to: :confirm
```

we can pass a block on each checkout step definition and work some logic to
figure if the step is required dynamically. e.g. the confirm step might only
be necessary for payment gateways that support payment profiles.

These conditional states present a situation where an order could transition
from delivery to one of payment, confirm or complete. In the default checkout,
we never want to transition from delivery to confirm, and therefore have removed
it using the `remove_transition` method of the Checkout DSL. The resulting
transitions between states look like the image below:

These two helper methods are provided on `Spree::Order` instances for your
convenience:

* `checkout_steps`: returns a list of all the potential states of the checkout.
* `has_step?`: Used to check if the current order fulfills the requirements for a specific state.

If you want a list of all the currently available states for the checkout, use
the `checkout_steps` method, which will return the steps in an array.

### Modifying the checkout flow

To add or remove steps to the checkout flow, you can use the `insert_checkout_step`
and `remove_checkout_step` helpers respectively.

The `insert_checkout_step` takes a `before` or `after` option to determine where to
insert the step:

```ruby
insert_checkout_step :new_step, before: :address
# or
insert_checkout_step :new_step, after: :address
```

The `remove_checkout_step` will remove just one checkout step at a time:

```ruby
remove_checkout_step :address
remove_checkout_step :delivery
```

What will happen here is that when a user goes to checkout, they will be asked
to (potentially) fill in their payment details and then (potentially) confirm
the order. This is the default behavior of the payment and the confirm steps
within the checkout. If they are not required to provide payment or confirmation
for this order then checking out this order will result in its immediate completion.

To completely re-define the flow of the checkout, use the `checkout_flow` helper:

```ruby
checkout_flow do
  go_to_state :payment
  go_to_state :complete
end
```

### Adding Logic Before or After a Particular Step

The [state_machines](https://github.com/state-machines/state_machines) 
gem allows you to implement callbacks before or after
transitioning to a particular step. These callbacks work similarly to 
[Active Record Callbacks](http://guides.rubyonrails.org/active_record_callbacks.html)
in that you can specify a method or block of code to be executed prior to or
after a transition. If the method executed in a before_transition returns false,
then the transition will not execute.

So, for example, if you wanted to verify that the user provides a valid zip code
before transitioning to the delivery step, you would first implement a
`valid_zip_code?` method, and then tell the state machine to run this method
before that transition, placing this code in a file called
`app/models/my_store/spree/order_decorator.rb`:

```ruby
::Spree::Order.state_machine.before_transition to: :delivery, do: :valid_zip_code?
```

This callback would prevent transitioning to the `delivery` step if
`valid_zip_code?` returns false.

## Storefront default Checkout

If you're not using the default Spree Storefront which comes with Spree Frontend gem you can skip this section.

#### Routes

Three custom routes in Spree Frontend handle all of the routing for a checkout:

```ruby
put '/checkout/update/:state', to: 'checkout#update', as: :update_checkout
get '/checkout/:state', to: 'checkout#edit', as: :checkout_state
get '/checkout', to: 'checkout#edit', as: :checkout
```

The `/checkout` route maps to the `edit` action of the
`Spree::CheckoutController`. A request to this route will redirect to the
current state of the current order. If the current order was in the **address** state, then a request to `/checkout` would redirect to `/checkout/address`.

The `/checkout/:state` route is used for the previously mentioned route, and
also maps to the `edit` action of `Spree::CheckoutController`.

The '/checkout/update/:state' route maps to the
`Spree::CheckoutController#update` action and is used in the checkout form to
update order data during the checkout process.

### Spree::CheckoutController

The `Spree::CheckoutController` drives the state of an order during checkout.
Since there is no "checkout" model, the `Spree::CheckoutController` is not a
typical RESTful controller. The spree_core and spree_auth_devise gems expose a
few different actions for the `Spree::CheckoutController`.

The `edit` action renders the checkout/edit.html.erb template, which then
renders a partial with the current state, such as
`app/views/spree/checkout/address.html.erb`. This partial shows state-specific
fields for the user to fill in. If you choose to customize the checkout flow to
add a new state, you will need to create a new partial for this state.

The `update` action performs the following:

* Updates the `current_order` with the parameters passed in from the current
  step.
* Transitions the order state machine using the `next` event after successfully
  updating the order.
* Executes callbacks based on the new state after successfully transitioning.
* Redirects to the next checkout step if the `current_order.state` is anything
  other than `complete`, else redirect to the `order_path` for `current_order`

<alert kind="note">
  For security reasons, the `Spree::CheckoutController` will not update the
  order once the checkout process is complete. It is therefore impossible for an
  order to be tampered with (ex. changing the quantity) after checkout.
</alert>

### Filters

The `spree_core` and the default authentication gem (`spree_auth_devise`) gems
define several `before_actions` for the `Spree::CheckoutController`:

* `load_order`: Assigns the `@order` instance variable and sets the `@order.state` to the `params[:state]` value. This filter also runs the "before" callbacks for the current state.
* `check_authorization`: Verifies that the `current_user` has access to `current_order`.
* `check_registration`: Checks the registration status of `current_user` and redirects to the registration step if necessary.

## Checkout Customization

It is possible to override the default checkout workflow to meet your store's needs.

### Customizing an Existing Step

Spree allows you to customize the individual steps of the checkout process.
There are a few distinct scenarios that we'll cover here.

* Adding logic either before or after a particular step.
* Customizing the view for a particular step.

### Customizing the View for a Particular Step

Each of the default checkout steps has its own partial defined in the
spree frontend `app/views/spree/checkout` directory. Changing the view for an
existing step is as simple as overriding the relevant partial in your site
extension.

### The Checkout View

After creating a checkout step, you'll need to create a partial for the checkout
controller to load for your custom step. If your additonal checkout step is
`new_step` you'll need to a `spree/checkout/_new_step.html.erb` partial.

### The Checkout "Breadcrumb"

The Spree code automatically creates a progress "breadcrumb" based on the
available checkout states. The states listed in the breadcrumb come from the
`Spree::Order#checkout_steps` method. If you add a new state you'll want to add
a translation for that state in the relevant translation file located in the
`config/locales` directory of your extension or application:

```ruby
en:
  order_state:
    new_step: New Step
```
