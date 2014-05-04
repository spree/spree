## Spree 2.3.0 (unreleased) ##

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
