---
title: Security
---

## Overview

Proper application design, intelligent programming, and secure infrastructure
are all essential in creating a secure e-commerce store using any software
(Spree included.)  The Spree team has done its best to provide you with the
tools to create a secure and profitable web presence but it is up to you to take
these tools and put them in good practice. We highly recommend reading and
understanding the [Rails Security Guide](http://guides.rubyonrails.org/security.html)

## Reporting Security Issues

Please do not announce potential security vulnerabilities in public. We have a
[dedicated email address](mailto:security@spreecommerce.com).
We will work quickly to determine the severity of the issue and
provide a fix for the appropriate versions.

## Authentication

If you install spree_auth_devise when setting up your app, we use a third party
authentication library for Ruby known as
[Devise](https://github.com/plataformatec/devise). This library provides a host
of useful functionality that is in turn available to Spree, including the
following features:

* Authentication
* Strong password encryption (with the ability to specify your own algorithms)
* "Remember Me" cookies
* "Forgot my password" emails
* Token-based access (for REST API)

### Devise Configuration

***
A default Spree install comes with the
[spree_auth_devise](https://github.com/psree/spree_auth_devise) gem, which
provides authentication for Spree using Devise. This section of the guide covers
the default setup. If you're using your own authentication, please consult the
manual for that authentication engine.
***

We have configured Devise to handle only what is needed to authenticate with a
Spree site. The following details cover the default configurations:

* Passwords are stored in the database encrypted with the salt.
* User authentication is done through the database query.
* User registration is enabled and the user's login is available immediately (no
  validation emails).
* There is a remember me and password recovery tool built in and enabled through
  Devise.


***
These configurations represent a reasonable starting point for a typical
e-commerce site.  Devise can be configured extensively to allow for a different
feature set but that is currently beyond the scope of this document.  Developers
are encouraged to visit the [Devise
wiki](https://github.com/plataformatec/devise/wiki) for more details.
***

### REST API

The REST API behaves slightly differently than a standard user. First, an admin
has to create the access key before any user can query the REST API. This
includes generating the key for the admin him/herself. This is not the case if
`Spree::Api::Config[:requires_authentication]` is set to `false`.

***
In cases where `Spree::Api::Config[:requires_authentication] is set to `false`,
read-only requests in the API will be possible for all users. For actions that
modify data within Spree, a user will need to have an API key and then their
user record would need to have permission to perform those actions.
***

It is up to you to communicate that key. As an added measure, this
authentication has to occur on every request made through the REST API as no
session or cookies are created or stored for the REST API.

### Authorization

Spree uses the excellent [CanCan](https://github.com/ryanb/cancan) gem to provide
authorization services.  If you are unfamiliar with it, you should take a look
at Ryan Bates' [excellent screencast](http://railscasts.com/episodes/192-authorization-with-cancan) on the topic
(or read the [transcribed version](http://asciicasts.com/episodes/192-authorization-with-cancan)).  A
detailed explanation of CanCan is beyond the scope of this guide.

### Default Rules

The follow Spree source code is taken from `ability.rb` and provides some
insight into the default authorization rules:

```ruby
if user.respond_to?(:has_spree_role?) && user.has_spree_role?('admin')
  can :manage, :all
else
  #############################
  can [:read,:update,:destroy], Spree.user_class, :id => user.id
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
end```


The above rule set has the following practical effects for Spree users

* Admin role can access anything (the rest of the rules are ignored)
* Anyone can create a `User`, only the user associated with an account can
  perform read or update operations for that user.
* Anyone can create an `Order`, only the user associated with the order can
  perform read or update operations.
* Anyone can read product pages and look at lists of `Products` (including
  search operations).
* Anyone can read or view a list of `Taxons`.

### Enforcing the Rules

CanCan is only effective in enforcing authorization rules if it's asked.  In
other words, if the source code does not check permissions there is no way to
deny access based on those permissions.  This is generally handled by adding the
appropriate code to your Rails controllers. For more information please see the
[CanCan Wiki](https://github.com/ryanb/cancan/wiki).

### Custom Authorization Rules

We have modified the original CanCan concept to make it easier for extension
developers and end users to add their own custom authorization rules.  For
instance, if you have an "artwork extension" that allows users to attach custom
artwork to an order, you will need to add rules so that they have permissions to
do so.

The trick to adding custom authorization rules is to add an `AbilityDecorator`
to your extension and then to register these abilities.  The following code is
an example of how to restrict access so that only the owner of the artwork can
update it or view it.

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

Ability.register_ability(AbilityDecorator)```

### Tokenized Permissions

There are situations where it may be desirable to restrict access to a
particular resource without requiring a user to authenticate in order to have
that access.  Spree allows so-called "guest checkouts" where users just supply
an email address and they're not required to create an account.  In these cases
you still want to restrict access to that order so only the original customer
can see it.  The solution is to use a "tokenized" URL.

http://example.com/orders?token=aidik313dsfs49d

Spree provides a `TokenizedPermission` model used to grant access to various
resources through a secure token.  This model works in conjunction with the
`Spree::TokenResource` module which can be used to add tokenized access
functionality to any Spree resource.

```ruby
module Spree
  module Core
    module TokenResource
      module ClassMethods
        def token_resource
          has_one :tokenized_permission, :as => :permissable
          delegate :token, :to => :tokenized_permission, :allow_nil => true
          after_create :create_token
        end
      end

      def create_token
        permission = build_tokenized_permission
        permission.token = token = ::SecureRandom::hex(8)
        permission.save!
        token
      end

      def self.included(receiver)
        receiver.extend ClassMethods
      end
    end
  end
end

ActiveRecord::Base.class_eval { include Spree::Core::TokenResource }```


The `Order` model is one such model in Spree where this interface is already in
use.  The following code snippet shows how to add this functionality through the
use of the `token_resource` declaration:

```ruby
Spree::Order.class_eval do
  token_resource
end```

If we examine the default CanCan permissions for `Order` we can see how tokens
can be used to grant access in cases where the user is not authenticated.

```ruby
can :read, Spree::Order do |order, token|
  order.user == user || order.token && token == order.token
end

can :update, Spree::Order do |order, token|
  order.user == user || order.token && token == order.token
end

can :create, Spree::Order```

This configuration states that in order to read or update an order, you must be
either authenticated as the correct user, or supply the correct authorizing
token.

The final step is to ensure that the token is passed to CanCan when the
authorization is performed, which is done in the controller.

```ruby
authorize! action, resource, session[:access_token]```

Of course this also assumes that the token has been stored in the session.
Generally this can be achieved with a route that maps the token to the correct
parameter:

```ruby
get '/orders/:id/token/:token' => 'orders#show', :as => :token_order```

This is followed by a call to store the token in the session for possible future
access.

```ruby
  session[:access_token] ||= params[:token]```

## Credit Card Data

### PCI Compliance

All store owners wishing to process credit card transactions should be familiar
with [PCI Compliance](http://en.wikipedia.org/wiki/Pci_compliance).  Spree makes
absolutely no warranty regarding PCI compliance (or anything else for that
matter - see the [LICENSE](http://spreecommerce.com/license) for details.)  We
do, however, follow common sense security practices in handling credit card
data.

### Transmit Exactly Once

Spree uses extreme caution in its handling of credit cards.  In production mode,
credit card data is transmitted to Spree via SSL.  The data is immediately
relayed to your chosen payment gateway and then discarded.  The credit card data
is never stored in the database (not even temporarily) and it exists in memory
on the server for only a fraction of a second before it is discarded.

***
Spree does store the last four digits of the credit card and the
expiration month and date.  You could easily customize Spree further if you
wanted and opt out of storing even that little bit of information.
***

### Payment Profiles

Spree also supports the use of "payment profiles."  This means that you can
"store" a customer's credit card information in your database securely.  More
precisely you store a "token" that allows you to use the credit card again.  The
credit card gateway is actually the place where the credit card is stored.
Spree ends up storing a token that can be used to authorize new charges on that
same card without having to store sensitive credit card details.

***
Spree has out of the box support for [Authorize.net CIM](http://www.authorize.net/solutions/merchantsolutions/merchantservices/cim/)
payment profiles.
***

### Other Options

There are also third-party extensions for Paypal's [Express
Checkout](https://merchant.paypal.com/cgi-bin/marketingweb?cmd=_render-content&content_ID=merchant/express_checkout)
(formerly called Paypal Express.)  These types of checkout services handle
processing of the credit card information offsite (the data never touches your
server) and greatly simplify the requirements for PCI compliance.

[Braintree](https://braintrepayments.com) also offers a very
interesting gateway option that achieves a similar benefit to Express Checkout
but allows the entire process to appear to be taking place on the site.  In
other words, the customer never appears to leave the store during the checkout.
They describe this as a "transparent redirect."  The Braintree team is very
interested in helping other Ruby developers use their gateway and have provided
support to Spree developers in the past who were interested in using their
product.

## Security Alerts

Spree will periodically check for important security and release announcements.
You will see them on the administration console pages. Alerts may be dismissed
after you have read them. The automatic checking can be disabled under
"Configuration" => "General Settings", or by setting the
`Spree::Config[:check_for_alerts]` setting to `false`. Some configuration information is included
when checking so the alerts can be customized to your specific installation.
Here is an example of the configuration information included in the alert
request:

```json
{
  "name": "Spree Demo Site",
  "rails_version": "3.1.1",
  "version": "0.70.1",
  "rails_env": "production",
  "host": "www.spreecommerce.com"
}```

