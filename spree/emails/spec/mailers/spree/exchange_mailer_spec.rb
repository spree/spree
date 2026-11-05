require 'spec_helper'
require 'email_spec'

describe Spree::ExchangeMailer, type: :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:store) { @default_store }
  let(:order) { create(:shipped_order, store: store, customer: nil, email: 'guest@example.com') }
  let(:exchange) { create(:exchange, order: order, store: store) }

  it 'acknowledges the request, naming what goes back and what comes out' do
    message = described_class.requested_email(exchange)
    line = exchange.exchange_line_items.first

    expect(message.to).to eq([order.email])
    expect(message.subject).to include(exchange.number)
    expect(email_body(message)).to include(line.original_variant.product.name)
    expect(email_body(message)).to include(line.new_variant.name)
  end

  it 'says where to send the items once approved' do
    exchange.update_columns(status: 'approved', approved_at: Time.current)

    expect(email_body(described_class.approved_email(exchange))).to include(exchange.stock_location.name)
  end
end
