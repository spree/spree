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

  # Erasure reaches guest rows and removed addresses, so an access response
  # that skipped them would understate what the store holds — and what it is
  # about to wipe.
  describe 'history the account does not own' do
    let!(:guest_order) do
      create(:completed_order_with_totals, store: store).tap do |order|
        order.update_columns(customer_id: nil, email: 'buyer@example.com')
      end
    end

    it 'includes an order placed as a guest' do
      expect(payload[:orders].map { |o| o[:number] }).to include(guest_order.number)
    end

    it 'includes an address the person removed' do
      removed = create(:address, owner: customer, address1: '1 Old Street')
      removed.update_columns(deleted_at: 1.day.ago)

      expect(payload[:addresses].map { |a| a[:address1] }).to include('1 Old Street')
    end
  end

  it 'discloses a tax registration held on the account' do
    create(:tax_identifier, owner: customer)

    expect(payload[:tax_identifiers]).not_to be_empty
  end

  it 'includes a newsletter sign-up made before the account existed' do
    create(:newsletter_subscriber, store: store, email: customer.email).
      update_columns(customer_id: nil)

    expect(payload[:marketing_consent][:newsletter_subscriptions]).not_to be_empty
  end

  it 'produces a payload that survives a JSON round trip' do
    expect { JSON.parse(JSON.generate(payload)) }.not_to raise_error
  end

  # Whatever erasure treats as personal data, an access request has to
  # disclose. The two answer the same question about the same columns, so a
  # field reachable by one and not the other is a defect in whichever is
  # behind — usually the export, which is written per-section by hand.
  # Customer and order emails keep the casing they were typed in; newsletter
  # addresses are stored downcased. One person can therefore be recorded under
  # two spellings of the same address.
  describe 'an address the person typed differently' do
    let!(:guest_order) do
      create(:completed_order_with_totals, store: store).
        tap { |order| order.update_columns(customer_id: nil, email: customer.email.upcase) }
    end

    it 'includes a guest order placed under different casing' do
      numbers = payload[:orders].map { |order| order[:number] }

      expect(numbers).to include(guest_order.number)
    end

    it 'includes a newsletter sign-up under different casing' do
      create(:newsletter_subscriber, store: store, email: customer.email.downcase).
        update_columns(customer_id: nil)

      expect(payload[:marketing_consent][:newsletter_subscriptions]).not_to be_empty
    end
  end

  describe 'agreement with what erasure removes' do
    it 'discloses the tracking and merchant notes held against the account' do
      customer.update_columns(metadata: { 'crm_segment' => 'wholesale' })

      expect(payload[:account][:metadata]).to eq('crm_segment' => 'wholesale')
    end

    it 'discloses the address an order was placed from and its annotations' do
      order = create(:completed_order_with_totals, customer: customer, store: store)
      order.update_columns(last_ip_address: '203.0.113.9', metadata: { 'source' => 'campaign' })

      exported = payload[:orders].first

      expect(exported[:last_ip_address]).to eq('203.0.113.9')
      expect(exported[:metadata]).to eq('source' => 'campaign')
    end

    it 'discloses the same for an abandoned checkout' do
      cart = create(:cart, customer: customer, store: store)
      cart.update_columns(last_ip_address: '203.0.113.9', metadata: { 'source' => 'campaign' })

      exported = payload[:carts].first

      expect(exported[:last_ip_address]).to eq('203.0.113.9')
      expect(exported[:metadata]).to eq('source' => 'campaign')
    end
  end
end
