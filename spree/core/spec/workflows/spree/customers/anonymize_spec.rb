require 'spec_helper'

RSpec.describe Spree::Customers::Anonymize do
  let(:store) { @default_store }
  let(:customer) { create(:customer, email: 'buyer@example.com', first_name: 'Ada', last_name: 'Lovelace', phone: '+44 20 7946 0958') }

  subject(:result) { described_class.call(customer: customer, store: store) }

  describe 'the account' do
    it 'replaces the identifying fields and keeps the row' do
      result
      customer.reload

      expect(customer.email).to match(/\Aanonymized-[0-9a-f-]+@invalid\z/)
      expect(customer.first_name).to eq('Redacted')
      expect(customer.last_name).to eq('Redacted')
      expect(customer.phone).to be_nil
      expect(customer).to be_persisted
    end

    it 'stamps when the erasure happened' do
      expect { result }.to change { customer.reload.anonymized_at }.from(nil)
    end

    it 'withdraws marketing consent and records why' do
      customer.update!(accepts_email_marketing: true)

      result
      customer.reload

      expect(customer.accepts_email_marketing).to be(false)
      expect(customer.email_marketing_consent_source).to eq('anonymization')
    end

    it 'refuses a customer already anonymized' do
      described_class.call(customer: customer, store: store)

      second = described_class.call(customer: customer.reload, store: store)

      expect(second).to be_failure
    end
  end

  describe 'the address book' do
    let!(:address) { create(:address, owner: customer, firstname: 'Ada', address1: '5 Baker Street', zipcode: '90210', phone: '+1 555 0142') }

    it 'redacts the street line and phone but keeps the jurisdiction' do
      original_country = address.country_code
      original_city = address.city

      result
      address.reload

      expect(address.address1).to eq('Redacted')
      expect(address.firstname).to eq('Redacted')
      expect(address.phone).to be_nil
      expect(address.country_code).to eq(original_country)
      expect(address.city).to eq(original_city)
    end

    it 'truncates the postcode rather than clearing it' do
      result

      expect(address.reload.zipcode).to eq('90')
    end

    it 'soft-deletes the customer\'s own entries' do
      result

      expect(address.reload.deleted_at).to be_present
    end

    it 'reaches an address the customer had already removed' do
      old_address = create(:address, owner: customer, address1: '1 Old Street', firstname: 'Ada')
      old_address.update_columns(deleted_at: 1.day.ago)

      result
      old_address.reload

      expect(old_address.address1).to eq('Redacted')
      expect(old_address.firstname).to eq('Redacted')
    end
  end

  describe 'past orders' do
    let(:order) { create(:completed_order_with_totals, customer: customer, store: store) }

    before do
      order.update_columns(email: 'buyer@example.com', customer_note: 'leave with neighbour', last_ip_address: '203.0.113.4')
    end

    it 'keeps the financial record intact' do
      original_total = order.total
      original_item_total = order.item_total
      line_item_count = order.line_items.count

      result
      order.reload

      expect(order.total).to eq(original_total)
      expect(order.item_total).to eq(original_item_total)
      expect(order.line_items.count).to eq(line_item_count)
      expect(order).to be_persisted
    end

    it 'scrubs the personal data attached to it' do
      result
      order.reload

      expect(order.email).to eq(customer.reload.email)
      expect(order.customer_note).to be_nil
      expect(order.last_ip_address).to be_nil
    end

    it 'redacts the address snapshot but leaves the tax jurisdiction readable' do
      ship_address = order.ship_address
      original_state = ship_address.state_code
      original_country = ship_address.country_code

      result
      ship_address.reload

      expect(ship_address.address1).to eq('Redacted')
      expect(ship_address.lastname).to eq('Redacted')
      expect(ship_address.state_code).to eq(original_state)
      expect(ship_address.country_code).to eq(original_country)
    end

    it 'leaves the snapshot readable rather than deleting it' do
      ship_address_id = order.ship_address_id

      result

      expect(Spree::Address.find_by(id: ship_address_id)).to be_present
    end
  end

  describe 'credentials and sessions' do
    let!(:refresh_token) do
      Spree::RefreshToken.create!(
        user: customer, token: SecureRandom.hex(16), expires_at: 1.week.from_now,
        audience: 'storefront_api', ip_address: '203.0.113.4', user_agent: 'Mozilla/5.0'
      )
    end

    it 'signs the account out everywhere' do
      expect { result }.to change { Spree::RefreshToken.where(user_id: customer.id).count }.to(0)
    end
  end

  describe 'consent history' do
    let!(:consent) do
      create(:consent_record, store: store, owner: customer, email: 'buyer@example.com', ip_address: '203.0.113.4')
    end

    it 'keeps the proof that consent was given' do
      result

      expect(consent.reload).to be_present
      expect(consent.purpose).to eq(Spree::ConsentRecord::TERMS_OF_SERVICE)
      expect(consent.recorded_at).to be_present
    end

    it 'removes the contact details attached to it' do
      result
      consent.reload

      expect(consent.email).to be_nil
      expect(consent.ip_address).to be_nil
    end
  end

  describe 'an abandoned cart' do
    let!(:cart) do
      create(:cart, customer: customer, store: store).tap do |record|
        record.update_columns(email: 'buyer@example.com', last_ip_address: '203.0.113.4',
                              customer_note: 'ring the bell')
      end
    end

    it 'scrubs the personal data on it' do
      result
      cart.reload

      expect(cart.email).to eq(customer.reload.email)
      expect(cart.last_ip_address).to be_nil
      expect(cart.customer_note).to be_nil
    end
  end

  describe 'traces left by guest checkout' do
    let!(:guest_subscriber) do
      create(:newsletter_subscriber, store: store, email: 'buyer@example.com').tap do |record|
        record.update_columns(customer_id: nil)
      end
    end

    let!(:guest_consent) do
      order = create(:completed_order_with_totals, store: store)
      create(:consent_record, store: store, owner: order, email: 'buyer@example.com',
                              ip_address: '203.0.113.4')
    end

    it 'removes a subscription made before the account existed' do
      result

      expect(Spree::NewsletterSubscriber.where(email: 'buyer@example.com')).to be_empty
    end

    it 'scrubs consent recorded against the order rather than the account' do
      result
      guest_consent.reload

      expect(guest_consent.email).to be_nil
      expect(guest_consent.ip_address).to be_nil
    end
  end

  it 'announces the erasure' do
    expect(customer).to receive(:publish_event).with('customer.anonymized', hash_including(:store_id))

    described_class.call(customer: customer, store: store)
  end

  describe 'the veto hook' do
    let(:handler) { ->(workflow) { workflow.reject!('legal hold') } }

    before { Spree.hooks.register('customers.anonymize.validate', handler) }
    after { Spree.hooks.unregister('customers.anonymize.validate', handler) }

    it 'lets a host app refuse the erasure' do
      expect(result).to be_failure
      expect(customer.reload.anonymized_at).to be_nil
      expect(customer.reload.email).to eq('buyer@example.com')
    end
  end
end
