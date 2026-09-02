require 'spec_helper'

RSpec.describe Spree::Customers::DataExport do
  let(:store) { @default_store }
  let(:customer) { create(:customer, email: 'buyer@example.com', first_name: 'Ada', last_name: 'Lovelace') }

  subject(:payload) { described_class.new(customer: customer, store: store).call }

  it 'reports the account the request is about' do
    expect(payload[:account]).to include(
      email: 'buyer@example.com',
      first_name: 'Ada',
      last_name: 'Lovelace'
    )
  end

  it 'stamps when the copy was produced' do
    expect(payload[:exported_at]).to be_present
  end

  it 'reports the marketing consent state alongside its provenance' do
    customer.update!(accepts_email_marketing: true)

    expect(payload[:marketing_consent]).to include(accepts_email_marketing: true)
    expect(payload[:marketing_consent][:consent_updated_at]).to be_present
  end

  it 'includes the consent history behind the booleans' do
    create(:consent_record, store: store, owner: customer, purpose: Spree::ConsentRecord::TERMS_OF_SERVICE)

    purposes = payload[:consent_records].map { |record| record[:purpose] }

    expect(purposes).to include(Spree::ConsentRecord::TERMS_OF_SERVICE)
  end

  context 'with orders' do
    let!(:order) { create(:completed_order_with_totals, customer: customer, store: store) }

    it 'includes completed orders with their line items' do
      exported = payload[:orders].first

      expect(exported[:number]).to eq(order.number)
      expect(exported[:line_items]).to be_present
    end

    it 'leaves incomplete carts out' do
      create(:order, customer: customer, store: store)

      expect(payload[:orders].length).to eq(1)
    end
  end

  context 'with an address book' do
    let!(:address) { create(:address, owner: customer, address1: '5 Baker Street') }

    it 'includes the addresses the shop holds' do
      expect(payload[:addresses].map { |a| a[:address1] }).to include('5 Baker Street')
    end
  end

  describe 'abandoned checkouts' do
    let!(:cart) { create(:cart, customer: customer, store: store) }

    it 'discloses them, because they are retained data about this person' do
      expect(payload[:carts].length).to eq(1)
    end
  end

  describe 'consent given before the account existed' do
    let!(:guest_consent) do
      order = create(:completed_order_with_totals, store: store)
      create(:consent_record, store: store, owner: order, email: 'buyer@example.com',
                              purpose: Spree::ConsentRecord::EMAIL_MARKETING)
    end

    it 'includes rows the order owns but which are about this person' do
      purposes = payload[:consent_records].map { |record| record[:purpose] }

      expect(purposes).to include(Spree::ConsentRecord::EMAIL_MARKETING)
    end
  end

  it 'produces a payload that survives a JSON round trip' do
    expect { JSON.parse(JSON.generate(payload)) }.not_to raise_error
  end
end
