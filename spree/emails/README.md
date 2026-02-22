# Spree Emails

[![Gem Version](https://badge.fury.io/rb/spree_emails.svg)](https://badge.fury.io/rb/spree_emails)

Spree Emails provides transactional email templates and mailers for Spree Commerce, handling order confirmations, shipment notifications, and other customer communications.

## Overview

This gem includes:

- **Order Mailer** - Order confirmation and cancellation emails
- **Shipment Mailer** - Shipping and delivery notifications
- **Reimbursement Mailer** - Refund notifications
- **Event Subscribers** - Automatic email triggers on store events
- **Email Templates** - Customizable HTML and text templates

## Installation

```bash
bundle add spree_emails
```

## Email Types

### Order Emails

- **Order Confirmation** - Sent when an order is completed
- **Order Cancellation** - Sent when an order is cancelled

### Shipment Emails

- **Shipment Notification** - Sent when a shipment is shipped
- **Delivery Confirmation** - Sent when tracking shows delivered

### Reimbursement Emails

- **Refund Notification** - Sent when a reimbursement is processed

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

### Overriding Templates

Copy email templates to your application:

```bash
# Copy all email templates
cp -r $(bundle show spree_emails)/app/views/spree/mailer app/views/spree/

# Or copy specific templates
cp $(bundle show spree_emails)/app/views/spree/mailer/order_mailer/confirm_email.html.erb \
   app/views/spree/mailer/order_mailer/
```

### Template Structure

```
app/views/spree/mailer/
├── order_mailer/
│   ├── confirm_email.html.erb
│   ├── confirm_email.text.erb
│   ├── cancel_email.html.erb
│   └── cancel_email.text.erb
├── shipment_mailer/
│   ├── shipped_email.html.erb
│   └── shipped_email.text.erb
└── reimbursement_mailer/
    ├── reimbursement_email.html.erb
    └── reimbursement_email.text.erb
```

### Custom Mailer

Create custom mailers by extending Spree's base mailer:

```ruby
# app/mailers/spree/order_mailer_decorator.rb
module Spree
  module OrderMailerDecorator
    def confirm_email(order, resend = false)
      @custom_data = fetch_custom_data(order)
      super
    end

    private

    def fetch_custom_data(order)
      # Custom logic
    end
  end
end

Spree::OrderMailer.prepend(Spree::OrderMailerDecorator)
```

### Adding New Email Types

```ruby
# app/mailers/spree/custom_mailer.rb
module Spree
  class CustomMailer < BaseMailer
    def welcome_email(user)
      @user = user
      mail(to: @user.email, subject: 'Welcome to our store!')
    end
  end
end
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
      user = Spree.user_class.find_by(id: user_id)
      return unless user

      Spree::CustomMailer.welcome_email(user).deliver_later
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

## Testing

Preview emails in development:

```ruby
# test/mailers/previews/spree/order_mailer_preview.rb
module Spree
  class OrderMailerPreview < ActionMailer::Preview
    def confirm_email
      order = Spree::Order.complete.last
      Spree::OrderMailer.confirm_email(order)
    end
  end
end
```

Visit `http://localhost:3000/rails/mailers/spree/order_mailer/confirm_email`

Run the test suite:

```bash
cd emails
bundle exec rake test_app  # First time only
bundle exec rspec
```

## Documentation

- [Email Customization Guide](https://docs.spreecommerce.org/developer/customization/emails)
- [Events System](https://docs.spreecommerce.org/developer/core-concepts/events)