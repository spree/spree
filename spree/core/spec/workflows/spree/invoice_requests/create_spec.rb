require 'spec_helper'

RSpec.describe Spree::InvoiceRequests::Create do
  let(:order) { create(:completed_order_with_totals) }

  before { order.update_columns(status: 'placed') }

  it 'records the request and publishes order.invoice_requested', :events do
    allow(Spree::Events).to receive(:publish).and_call_original
    result = described_class.call(order: order, company_name: 'Acme GmbH', tax_id: 'DE123456789')

    expect(Spree::Events).to have_received(:publish).with('order.invoice_requested', any_args)
    expect(result).to be_success
    expect(result.value).to have_attributes(status: 'open', company_name: 'Acme GmbH', store: order.store)
  end

  it 'refuses an order that already has an invoice' do
    create(:invoice, order: order)

    expect(described_class.call(order: order)).to be_failure
  end

  it 'refuses once the window has passed' do
    order.update_columns(completed_at: 120.days.ago)

    expect(described_class.call(order: order)).to be_failure
  end

  it 'refuses when the store accepts no requests' do
    allow(order.store).to receive(:preferred_invoice_request_window_days).and_return(0)

    expect(described_class.call(order: order)).to be_failure
  end

  it 'saves the billing address with the request' do
    params = { first_name: 'Ada', last_name: 'Lovelace', address1: '1 Main St', city: 'Berlin',
               postal_code: '10115', country_code: 'DE', company: 'Acme GmbH' }

    result = described_class.call(order: order, billing_address_params: params)

    expect(result.value.billing_address).to have_attributes(city: 'Berlin', company: 'Acme GmbH')
  end

  it 'leaves no address behind when the request is refused' do
    create(:invoice, order: order)
    params = { first_name: 'Ada', last_name: 'Lovelace', address1: '1 Main St', city: 'Berlin', postal_code: '10115', country_code: 'DE' }

    expect { described_class.call(order: order, billing_address_params: params) }.not_to change(Spree::Address, :count)
  end

  it 'refuses a second open request' do
    described_class.call(order: order)

    expect(described_class.call(order: order)).to be_failure
  end
end
