# spree_legacy_emails

Spree 6.0 renders every transactional email from a Liquid template written in MJML. This gem keeps the pre-6.0 ERB emails, and any ERB overrides your app has of them, rendering unchanged for one more release while you port them to Liquid.

```ruby
# Gemfile
gem 'spree_legacy_emails'
```

With the gem installed, an email renders from the first of:

1. your app's `app/views/spree/<mailer>/<email>.liquid`
2. an ERB view at the same path — yours, or this gem's
3. the Liquid template Spree ships

So you can port one email at a time: add its `.liquid` file and the ERB view stops being used. Every ERB email logs a deprecation warning the first time it renders.

This gem is removed in Spree 6.1. See the [email templates guide](https://spreecommerce.org/docs/developer/customization/emails) for porting.
