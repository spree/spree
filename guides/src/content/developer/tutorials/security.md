---
title: Security
section: advanced
---

## Overview

Proper application design, intelligent programming, and secure infrastructure are all essential in creating a secure e-commerce store using any software (Spree included). The Spree team has done its best to provide you with the tools to create a secure and profitable web presence, but it is up to you to take these tools and put them in good practice. We highly recommend reading and understanding the [Rails Security Guide](http://guides.rubyonrails.org/security.html).

## Reporting Security Issues

Please do not announce potential security vulnerabilities in public. We have a [dedicated email address](mailto:hello@spreecommerce.org). We will work quickly to determine the severity of the issue and provide a fix for the appropriate versions. We will credit you with the discovery of this patch by naming you in a blog post.

If you would like to provide a patch yourself for the security issue **do not open a pull request for it**. Instead, create a commit on your fork of Spree and run this command:

```bash
git format-patch HEAD~1..HEAD --stdout > patch.txt
```

This command will generate a file called `patch.txt` with your changes. Please email a description of the patch along with the patch itself to our [dedicated email address](mailto:hi@spreecommerce.org).

## Authentication

If you install spree_auth_devise when setting up your app, we use a third party authentication library for Ruby known as [Devise](https://github.com/plataformatec/devise). This library provides a host of useful functionality that is in turn available to Spree, including the following features:

* Authentication
* Strong password encryption (with the ability to specify your own algorithms)
* "Remember Me" cookies
* "Forgot my password" emails
* Token-based access (for REST API)

### Devise Configuration

<alert kind="note">
A default Spree install comes with the [spree_auth_devise](https://github.com/spree/spree_auth_devise) gem, which provides authentication for Spree using Devise. This section of the guide covers the default setup. If you're using your own authentication, please consult the manual for that authentication engine.
</alert>

We have configured Devise to handle only what is needed to authenticate with a Spree site. The following details cover the default configurations:

* Passwords are stored in the database encrypted with the salt.
* User authentication is done through the database query.
* User registration is enabled and the user's login is available immediately (no validation emails).
* There is a remember me and password recovery tool built in and enabled through Devise.

These configurations represent a reasonable starting point for a typical e-commerce site. Devise can be configured extensively to allow for a different feature set but that is currently beyond the scope of this document. Developers are encouraged to visit the [Devise wiki](https://github.com/plataformatec/devise/wiki) for more details.

### Legacy REST API v1

The REST API behaves slightly differently than a standard user. First, an admin has to create the access key before any user can query the REST API. This includes generating the key for the admin him/herself. This is not the case if `Spree::Api::Config[:requires_authentication]` is set to `false`.

In cases where `Spree::Api::Config[:requires_authentication]` is set to `false`, read-only requests in the API will be possible for all users. For actions that modify data within Spree, a user will need to have an API key and then their user record would need to have permission to perform those actions.

It is up to you to communicate that key. As an added measure, this authentication has to occur on every request made through the REST API as no session or cookies are created or stored for the REST API.

### Authorization

Spree uses the excellent [CanCanCan](https://github.com/CanCanCommunity/cancancan) gem to provide authorization services. A detailed explanation of CanCanCan is beyond the scope of this guide.

### Default Rules

The follow Spree source code is taken from `ability.rb` and provides some insight into the default authorization rules:

```ruby
if user.respond_to?(:has_spree_role?) && user.has_spree_role?('admin')
  can :manage, :all
else
  #############################
  can [:read,:update,:destroy], Spree.user_class, id: user.id
  can :create, Spree.user_class
  #############################
  can :read, Order do |order, token|
    order.user == user || order.token && token == order.token
  end
  can :update, Order do |order, token|
    order.user == user || order.token && token == order.token
  end
  can :create, Order

  can :read, Address do |address|
    address.user == user
  end

  #############################
  can :read, Product
  can :index, Product
  #############################
  can :read, Taxon
  can :index, Taxon
  #############################
end
```

The above rule set has the following practical effects for Spree users

* Admin role can access anything (the rest of the rules are ignored)
* Anyone can create a `User`, only the user associated with an account can perform read or update operations for that user.
* Anyone can create an `Order`, only the user associated with the order can perform read or update operations.
* Anyone can read product pages and look at lists of `Products` (including search operations).
* Anyone can read or view a list of `Taxons`.

### Enforcing the Rules

CanCanCan is only effective in enforcing authorization rules if it's asked. In other words, if the source code does not check permissions there is no way to deny access based on those permissions. This is generally handled by adding the appropriate code to your Rails controllers. For more information please see the [CanCanCan Wiki](https://github.com/CanCanCommunity/cancancan/wiki).

### Custom Authorization Rules

We have modified the original CanCanCan concept to make it easier for extension developers and end users to add their own custom authorization rules. For instance, if you have an "artwork extension" that allows users to attach custom artwork to an order, you will need to add rules so that they have permissions to do so.

The trick to adding custom authorization rules is to add an `AbilityDecorator` to your extension and then to register these abilities. The following code is an example of how to restrict access so that only the owner of the artwork can update it or view it.

```ruby
class AbilityDecorator
  include CanCan::Ability
  def initialize(user)
    can :read, Artwork do |artwork|
      artwork.order && artwork.order.user == user
    end
    can :update, Artwork do |artwork|
      artwork.order && artwork.order.user == user
    end
  end
end

Spree::Ability.register_ability(AbilityDecorator)
```

### Custom Roles in the Admin Namespace

If you plan on allowing a custom role you create to access the Spree administrative
panels, there are a couple of considerations to keep in mind.

Spree authorizes all of its administrative panels with two CanCanCan authorization
commands: `:admin` and the name of the action being authorized. If you want a
custom role to be able to access a particular admin panel, you have to specify
that your role *can* access both :admin and the name of the action on the relevant
resource. For example, if you want your Sales Representatives to be able to access the Admin
Orders panel without giving them access to anything else in the Admin namespace,
you would have to specify the following in an `AbilityDecorator`:

```ruby
class AbilityDecorator
  include CanCan::Ability
  def initialize(user)
    if user.respond_to?(:has_spree_role?) && user.has_spree_role?('sales_rep')
      can [:admin, :index, :show], Spree::Order
    end
  end
end

Spree::Ability.register_ability(AbilityDecorator)
```

This is required by the following code in Spree's `Admin::BaseController` which
is the controller every controller in the Admin namespace inherits from.

```ruby
def authorize_admin
  if respond_to?(:model_class, true) && model_class
    record = model_class
  else
    record = Object
  end
  authorize! :admin, record
  authorize! action, record
end
```

If you need to create custom controllers for your own models under the Admin
namespace, you will need to manually specify the model your controller manipulates
by defining a `model_class` method in that controller.

```ruby
module Spree
  module Admin
    class WidgetsController < BaseController
      def index
        # Relevant code in here
      end
    private
      def model_class
        Widget
      end
    end
  end
end
```

This is necessary because CanCanCan cannot, by default, detect the model used to
authorize controllers under the Admin namespace. By specifying `model_class`, Spree
knows what to tell CanCanCan to use to authorize your controller.

If you inherit from `ResourceController` instead of directly `BaseController`, and if you define new
collection actions, you need to override  `ResourceController#collection_actions` which contains only `[:index]` by default.

```ruby
module Spree
  module Admin
    class WidgetsController < ResourceController
      def index
        # Relevant code in here
      end

     def new_coll_action
        # relevant code
     end

    def collection_actions
        [:index, :new_coll_action]
    end
    private
      def model_class
        Widget
      end
    end
  end
end
```

### Tokenized Permissions

There are situations where it may be desirable to restrict access to a particular resource without requiring a user to authenticate in order to have that access. Spree allows so-called "guest checkouts" where users just supply an email address and they're not required to create an account. In these cases you still want to restrict access to that order so only the original customer can see it. The solution is to use a "tokenized" URL.

http://example.com/orders?token=aidik313dsfs49d

If we examine the default CanCanCan permissions for `Order` we can see how tokens can be used to grant access in cases where the user is not authenticated.

```ruby
can :read, Spree::Order do |order, token|
  order.user == user || order.token && token == order.token
end

can :update, Spree::Order do |order, token|
  order.user == user || order.token && token == order.token
end

can :create, Spree::Order
```

This configuration states that in order to read or update an order, you must be either authenticated as the correct user, or supply the correct authorizing token.

The final step is to ensure that the token is passed to CanCanCan when the authorization is performed, which is done in the controller.

```ruby
authorize! action, resource, session[:access_token]
```

## Credit Card Data

### PCI Compliance

All store owners wishing to process credit card transactions should be familiar with [PCI Compliance](http://en.wikipedia.org/wiki/Pci_compliance). Spree makes absolutely no warranty regarding PCI compliance (or anything else for that matter - see the [LICENSE](https://github.com/spree/spree/blob/master/license.md) for details.) We do, however, follow common sense security practices in handling credit card data.

### Transmit Exactly Once

Spree uses extreme caution in its handling of credit cards. In production mode, credit card data is transmitted to Spree via SSL. The data is immediately relayed to your chosen payment gateway and then discarded. The credit card data is never stored in the database (not even temporarily) and it exists in memory on the server for only a fraction of a second before it is discarded.

Spree does store the last four digits of the credit card and the expiration month and date.  You could easily customize Spree further if you wanted and opt out of storing even that little bit of information.

### Payment Profiles

Spree also supports the use of "payment profiles." This means that you can "store" a customer's credit card information in your database securely. More precisely you store a "token" that allows you to use the credit card again. The credit card gateway is actually the place where the credit card is stored. Spree ends up storing a token that can be used to authorize new charges on that same card without having to store sensitive credit card details.

Spree supports this for various payment gateways supported by [Spree Gateway](https://github.com/spree/spree_gateway).

### Other Options

There are also third-party extensions for Paypal's [Express Checkout](https://developer.paypal.com/docs/classic/products/express-checkout/) (formerly called Paypal Express.) These types of checkout services handle processing of the credit card information offsite (the data never touches your server) and greatly simplify the requirements for PCI compliance.

You can utilize PayPal Express Checkout via [Braintree vzero extension](https://github.com/spree-contrib/spree_braintree_vzero)
