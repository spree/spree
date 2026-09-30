# Spree Emails

[![Gem Version](https://badge.fury.io/rb/spree_emails.svg)](https://badge.fury.io/rb/spree_emails)

Spree Emails provides transactional email templates and mailers for Spree Commerce, handling order confirmations, shipment notifications, and other customer communications.

## Overview

This gem includes:

- **Mailers** for order confirmation, cancellation and payment links, multi-seller purchase confirmations, fulfillment notices, refunds, digital downloads, customer password resets and data exports, newsletter confirmation, company invitations and seller status changes
- **Event subscribers** that send them when store events happen
- **Liquid templates** written in MJML, one per email, that you can override

Staff emails (password resets, invitations, import and export results, disabled webhooks) live in `spree_core` and render the same way.

## Installation

```bash
bundle add spree_emails
```

## Configuration

Transactional emails are controlled per-store via the `send_consumer_transactional_emails` preference. This can be configured in the admin dashboard under Store Settings, or programmatically:

```ruby
# Enable/disable transactional emails for a store
store = Spree::Store.current
store.update(send_consumer_transactional_emails: true)
```

The sender address is configured via the `mail_from_address` attribute on each store:

```ruby
store.update(mail_from_address: 'orders@example.com')
```

### Action Mailer Configuration

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: 'smtp.example.com',
  port: 587,
  user_name: ENV['SMTP_USERNAME'],
  password: ENV['SMTP_PASSWORD'],
  authentication: 'plain',
  enable_starttls_auto: true
}
```

## Customization

### Overriding templates

Every email renders from a Liquid template at its Rails view path. To change one, create the file at the same path in your app — for example `app/views/spree/order_mailer/confirm_email.liquid` — starting from the copy in this gem's `app/views`. The layout around every email is `app/views/layouts/spree/base_mailer.liquid`.

Templates read plain data from serializers, never models: see the [email templates guide](https://spreecommerce.org/docs/developer/customization/emails) for the layout, partials, filters and escaping, and the [variable reference](https://spreecommerce.org/docs/developer/customization/email-variables) for what each template receives.

An ERB override of one of these emails from before Spree 6.0 is no longer used; Spree lists any it finds in the log at boot. Mailers of your own that render ERB views keep working, wrapped in the same layout.

### Adding new email types

Extend Spree's base mailer and render a Liquid template at the action's view path, passing the data it needs:

```ruby
# app/mailers/spree/custom_mailer.rb
module Spree
  class CustomMailer < BaseMailer
    def welcome_email(customer, store)
      @current_store = store

      with_store_locale(@current_store) do
        mail_template({ customer: email_data(customer, Spree.api.customer_serializer) }, to: customer.email)
      end
    end
  end
end
```

And its template, `app/views/spree/custom_mailer/welcome_email.liquid` (the front matter must open the file):

```liquid
---
subject: "Welcome to {{ store.name }}"
---
<mj-section>
  <mj-column css-class="hero">
    <mj-text mj-class="heading">Welcome, {{ customer.first_name }}!</mj-text>
  </mj-column>
</mj-section>
```

## Event Integration

Emails are triggered via Spree's event system. Create custom subscribers:

```ruby
# app/subscribers/my_app/custom_email_subscriber.rb
module MyApp
  class CustomEmailSubscriber < Spree::Subscriber
    subscribes_to 'customer.created'

    def handle(event)
      user_id = event.payload['id']
      user = Spree.customer_class.find_by(id: user_id)
      return unless user

      Spree::CustomMailer.welcome_email(user, Spree::Store.default).deliver_later
    end
  end
end
```

Then register the subscriber in an initializer:

```ruby
# config/initializers/spree.rb
Rails.application.config.after_initialize do
  Spree.subscribers << MyApp::CustomEmailSubscriber
end
```

## Disabling Emails

Disable transactional emails for a specific store:

```ruby
store = Spree::Store.current
store.update(send_consumer_transactional_emails: false)
```

This setting can also be managed in the admin dashboard under Store Settings.

To disable all Spree transactional emails globally, remove this gem from your application:

```bash
bundle remove spree_emails
```

### Using Third-Party Email Services

If you prefer to use a third-party email service like Klaviyo for transactional emails, you can use the [spree_klaviyo](https://github.com/spree/spree_klaviyo) extension. This allows you to leverage Klaviyo's email marketing platform for order confirmations, shipment notifications, and other transactional emails.

## Previewing emails

[ActionMailer previews](https://guides.rubyonrails.org/action_mailer_basics.html#previewing-and-testing-mailers) for every transactional email ship with this gem and are served automatically in development — no setup required. With a seeded development database, start the server and visit:

`http://localhost:3000/rails/mailers`

for example `http://localhost:3000/rails/mailers/spree/order/confirm_email`.

## Testing

Run the test suite:

```bash
cd emails
bundle exec rake test_app  # First time only
bundle exec rspec
```

## Documentation

- [Email Customization Guide](https://docs.spreecommerce.org/developer/customization/emails)
- [Events System](https://docs.spreecommerce.org/developer/core-concepts/events)
