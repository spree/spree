## Spree 2.3.0 (unreleased) ##

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
