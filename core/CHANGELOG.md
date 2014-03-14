## Spree 2.3.0 (unreleased) ##

*   Config settings related to mail have been removed. This includes
    `enable_mail_delivery`, `mail_bcc`, `intercept_email`,
    `override_actionmailer_config`, `mail_host`, `mail_domain`, `mail_port`,
    `secure_connection_type`, `mail_auth_type`, `smtp_username`, and
    `smtp_password`.

    These should instead be [configured on actionmailer directly](http://api.rubyonrails.org/classes/ActionMailer/Base.html#class-ActionMailer::Base-label-Configuration+options).
    The existing functionality can also be used by including the [spree_mail_settings](https://github.com/spree-contrib/spree_mail_settings) gem.

    John Hawthorn
