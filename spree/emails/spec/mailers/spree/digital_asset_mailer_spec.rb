require 'spec_helper'
require 'email_spec'

describe Spree::DigitalAssetMailer, type: :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:store) { @default_store }
  let(:order) { create(:order_with_line_items, store: store, email: 'test@example.com') }
  let(:line_item) { order.line_items.first }
  let(:digital_asset) { create(:digital_asset, variant: line_item.variant) }
  let!(:digital_link) { create(:digital_link, digital_asset: digital_asset, line_item: line_item) }

  subject(:message) { described_class.files_ready_email(order) }

  it 'goes to the customer' do
    expect(message.to).to eq([order.email])
    expect(message.from).to eq([store.mail_from_address])
  end

  it 'names the order in the subject' do
    expect(message.subject).to include(order.number)
  end

  it 'links every purchased file with an absolute url' do
    body = message.body.encoded

    expect(body).to include(digital_link.filename.to_s)
    expect(body).to match(%r{https?://[^"\s]+/api/v3/store/digital_links/#{digital_link.token}})
  end

  it 'is not sent when the order has no downloads' do
    plain_order = create(:order_with_line_items, store: store, email: 'plain@example.com')

    expect(described_class.files_ready_email(plain_order).to).to be_nil
  end
end
