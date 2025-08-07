# Spree Emails Rules

## Mailer Standards
- Inherit from `Spree::BaseMailer`
- Use proper email templates
- Include both HTML and text versions
- Handle missing records gracefully

```ruby
# ✅ Email mailer structure
module Spree
  class OrderMailer < BaseMailer
    def confirm_email(order)
      @order = order
      @store = order.store
      
      mail(
        to: order.email,
        from: from_address(@store),
        subject: Spree.t('order_mailer.confirm_email.subject', order: order.number)
      )
    end

    def cancel_email(order)
      @order = order
      @store = order.store
      
      mail(
        to: order.email,
        from: from_address(@store),
        subject: Spree.t('order_mailer.cancel_email.subject', order: order.number)
      )
    end

    private

    def from_address(store)
      store.mail_from_address.presence || Spree::Store.default.mail_from_address
    end
  end
end
```

## Template Standards
- Use consistent email layout
- Include store branding
- Ensure mobile responsiveness
- Test across email clients

```erb
<!-- ✅ Email template structure -->
<%= content_for :email_title, Spree.t('order_mailer.confirm_email.subject', order: @order.number) %>

<div class="email-container">
  <header class="email-header">
    <%= image_tag @store.logo.attached? ? @store.logo : 'spree/logo.png', 
                  alt: @store.name, 
                  class: 'store-logo' %>
    <h1><%= Spree.t('order_mailer.confirm_email.dear_customer') %></h1>
  </header>

  <main class="email-content">
    <p><%= Spree.t('order_mailer.confirm_email.order_summary_intro', order: @order.number) %></p>
    
    <%= render 'spree/order_mailer/order_details', order: @order %>
  </main>

  <footer class="email-footer">
    <%= render 'spree/shared/email_footer', store: @store %>
  </footer>
</div>
```

## Styling Standards
- Use inline CSS for email compatibility
- Include fallbacks for email clients
- Keep layouts simple and clean
- Test with email preview tools

## Asset Management
- Optimize images for email
- Use absolute URLs for assets
- Include alt text for images
- Consider dark mode support

## Testing Standards
- Test email delivery
- Preview emails in development
- Test across multiple email clients
- Verify links and formatting

```ruby
# ✅ Email spec
require 'spec_helper'

RSpec.describe Spree::OrderMailer, type: :mailer do
  let(:order) { create(:completed_order_with_totals) }
  let(:mail) { described_class.confirm_email(order) }

  describe '#confirm_email' do
    it 'renders the headers' do
      expect(mail.subject).to include(order.number)
      expect(mail.to).to eq([order.email])
      expect(mail.from).to eq([order.store.mail_from_address])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include(order.number)
      expect(mail.body.encoded).to include(order.user.email)
    end
  end
end
```

## Internationalization
- Support multiple languages
- Use proper locale selection
- Include currency formatting
- Handle right-to-left languages

## Performance
- Optimize email size
- Use efficient image formats
- Minimize external requests
- Consider email caching
