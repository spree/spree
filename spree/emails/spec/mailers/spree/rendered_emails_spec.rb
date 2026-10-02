require 'spec_helper'

# Every email Spree ships, rendered end to end from its Liquid template with
# customer-controlled text carrying HTML. Strict variables make a missing or
# misspelled field fail here rather than render blank.
describe 'rendered emails', type: :mailer do
  let(:payload) { '<a href="https://evil.test">Click to verify</a>' }
  let(:store) { @default_store }

  let(:order) do
    create(:completed_order_with_totals, store: store, email: 'buyer@example.com').tap do |order|
      order.bill_address.update_columns(first_name: payload)
      order.line_items.first.product.update_columns(name: payload)
      order.update_columns(po_number: payload)
    end
  end

  let(:order_group) { create(:order_group, :with_parcels, store: store, sellers_count: 2) }
  let(:seller) { create(:seller, store: store, name: payload, contact_email: 'seller@example.com') }
  let(:company) { create(:company, store: store, name: payload) }

  let(:emails) do
    {
      'order confirmation' => Spree::OrderMailer.confirm_email(order),
      'order cancellation' => Spree::OrderMailer.cancel_email(order),
      'new order notification' => Spree::OrderMailer.store_owner_notification_email(order),
      'payment link' => Spree::OrderMailer.payment_link_email(create(:order_with_line_items, store: store).id),
      'purchase confirmation' => Spree::OrderGroupMailer.confirm_email(order_group),
      'new purchase notification' => Spree::OrderGroupMailer.store_owner_notification_email(order_group),
      'fulfillment' => Spree::FulfillmentMailer.fulfilled_email(create(:shipped_order, store: store).fulfillments.first),
      'refund' => Spree::ReturnMailer.refunded_email(create(:received_return, store: store)),
      'password reset' => Spree::CustomerMailer.password_reset_email(create(:user, first_name: payload), 'token', store),
      'data export' => Spree::CustomerMailer.data_export_email(create(:data_request, store: store)),
      'newsletter confirmation' => Spree::NewsletterMailer.email_confirmation(create(:newsletter_subscriber, store: store)),
      'company invitation' => Spree::CompanyMailer.invitation_email(create(:company_invitation, company: company)),
      'seller approved' => Spree::SellerMailer.approved_email(seller),
      'seller suspended' => Spree::SellerMailer.suspended_email(seller),
      'seller rejected' => Spree::SellerMailer.rejected_email(seller)
    }
  end

  before { store.update_columns(new_order_notifications_email: 'owner@example.com') }

  it 'renders every email completely, with a subject and both parts' do
    emails.each do |name, message|
      html = message.html_part.decoded

      expect(message.subject).to be_present, name
      expect(html).not_to include('{{', '{%', '<mj-'), name
      expect(message.text_part.decoded).to be_present, name
    end
  end

  it 'escapes customer-controlled text everywhere it appears' do
    emails.each do |name, message|
      expect(message.html_part.decoded).not_to include('<a href="https://evil.test">'), name
    end

    expect(emails['order confirmation'].html_part.decoded).to include('&lt;a href=&quot;https://evil.test&quot;&gt;')
  end
end
