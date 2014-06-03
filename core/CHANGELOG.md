## Spree 2.3.0 (unreleased) ##

*   Drop first_name and last_name fields from spree_credit_cards.  Add
    first_name & last_name methods for now to keep ActiveMerchant happy.

    Jordan Brough

*   Replaced cookies.signed[:order_id] with cookies.signed[:guest_token].

    Now we are using a signed cookie to store the guests unique token
    in the browser.  This allows customers who close their browser to
    continue their shopping when they visit again.  More importantly
    it allows you as a store owner to uniquely identify your guests orders.
    Since we set cookies.signed[:guest_token] whenever a vistor comes
    you may also use this cookie token on other objects than just orders.
    For instance if a guest user wants to favorite a product you can
    assign the cookies.signed[:guest_token] value to a token field on your
    favorites model.  Which will then allow you to analyze the orders and
    favorites this user has placed before which is useful for recommendations.

    Jeff Dutil

*   Order#token is no longer fetched from another table.

    Both Spree::Core::TokeResource and Spree::TokenizedPersmission are deprecated.
    Order#token value is now persisted into spree_orders.guest_token. Main motivation
    here is save a few extra queries when creating an order. The TokenResource
    module was being of no use in spree core.

    NOTE: Watch out for the possible expensive migration that come along with this

    Washington L Braga Jr

*   Replaced session[:order_id] usage with cookies.signed[:order_id].

    Now we are using a signed cookie to store the order id on a guests
    browser client.  This allows customers who close their browser to
    continue their shopping when they visit again.
    Fixes #4319

    Jeff Dutil


*   Order#process_payments! no longer raises. Gateways must raise on failing authorizations.

    Now it's a Gateway or PaymentMethod responsability to raise a custom
    exception any time an authorization fails so that it can be rescued
    during checkout and proper action taken.

*   Assign request headers env to Payment when creating it via checkout.

    This might come in handy for some gateways, e.g. Adyen, actions that require
    data such as user agent and accept header to create user profiles. Previously
    we had no way to access the request headers from within a gateway class

*   More accurate and simpler Order#payment_state options.

    Balance Due. Paid. Credit Owed. Failed. These are the only possible values
    for order payment_state now. The previous `pending` state has been dropped
    and order updater logic greatly improved as it now mostly consider total
    values rather than doing last payment state checks.

    Huge thanks to dan-ding. See https://github.com/spree/spree/issues/4605

*   Config settings related to mail have been removed. This includes
    `enable_mail_delivery`, `mail_bcc`, `intercept_email`,
    `override_actionmailer_config`, `mail_host`, `mail_domain`, `mail_port`,
    `secure_connection_type`, `mail_auth_type`, `smtp_username`, and
    `smtp_password`.

    These should instead be [configured on actionmailer directly](http://api.rubyonrails.org/classes/ActionMailer/Base.html#class-ActionMailer::Base-label-Configuration+options).
    The existing functionality can also be used by including the [spree_mail_settings](https://github.com/spree-contrib/spree_mail_settings) gem.

    John Hawthorn

*   refactor the api to use a general importer in `lib/spree/importer/order.rb`

    Peter Berkenbosch

*   Ensure transition to payment processing state happens outside transaction.

    Chris Salzberg

*   Increase the precision of the amount/price columns in order for support other currencies. See https://github.com/spree/spree/issues/4657

    Gonzalo Moreno
