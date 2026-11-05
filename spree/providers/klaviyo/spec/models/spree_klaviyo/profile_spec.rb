require 'spec_helper'

RSpec.describe SpreeKlaviyo::Profile do
  let(:store) { @default_store }
  let(:customer) { create(:customer_with_addresses, email: 'ada@example.com', first_name: 'Ada', last_name: 'Lovelace') }

  def attributes(profile)
    profile.to_body.dig(:data, :attributes)
  end

  describe '.from_customer' do
    it "sends the customer's prefixed id as the external id" do
      body = described_class.from_customer(customer).to_body

      expect(body[:data][:type]).to eq('profile')
      expect(body[:data][:attributes]).to include(
        email: 'ada@example.com', first_name: 'Ada', last_name: 'Lovelace', external_id: customer.prefixed_id
      )
    end

    it 'sends the database id when the integration asks for it' do
      expect(attributes(described_class.from_customer(customer, use_database_ids: true))[:external_id]).to eq(customer.id.to_s)
    end

    it 'carries the location from the bill address' do
      address = customer.bill_address

      expect(attributes(described_class.from_customer(customer))[:location]).to include(
        address1: address.address1, city: address.city, zip: address.postal_code, country: address.country_code,
        region: address.state_name_text
      )
    end

    it 'leaves the location out without a bill address' do
      customer = create(:customer)

      expect(attributes(described_class.from_customer(customer))).not_to have_key(:location)
    end
  end

  describe '.from_order' do
    let(:order) { create(:completed_order_with_totals, store: store, customer: customer, email: customer.email) }

    it "carries the customer's external id" do
      expect(attributes(described_class.from_order(order))).to include(
        email: customer.email, external_id: customer.prefixed_id
      )
    end

    it 'takes the names and location from the bill address' do
      address = order.bill_address

      expect(attributes(described_class.from_order(order))).to include(
        first_name: address.first_name, last_name: address.last_name,
        location: hash_including(address1: address.address1, city: address.city)
      )
    end

    it 'identifies a guest by email alone' do
      guest_order = create(:completed_order_with_totals, store: store, customer: nil, email: 'guest@example.com')

      body = attributes(described_class.from_order(guest_order))

      expect(body[:email]).to eq('guest@example.com')
      expect(body).not_to have_key(:external_id)
    end
  end
end
