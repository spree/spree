require 'spec_helper'

# Shared battery for Spree::Purchase::AddressBook, run against BOTH hosts.
# Checkout moved from Order to Cart once already and silently lost this
# behavior (dedup, default promotion, ownership guard) — the shared examples
# exist so it cannot happen again without a red suite.
RSpec.shared_examples 'an address book host' do
  let(:store) { @default_store }
  let(:user) { create(:user) }

  let(:address_attributes) do
    attributes_for(:address).merge(user_id: nil)
  end

  describe '#ship_address_attributes=' do
    it 'creates a new address owned by the record user' do
      record.ship_address_attributes = address_attributes

      expect(record.ship_address).to be_persisted
      expect(record.ship_address.user).to eq(user)
    end

    it 'reuses an identical existing address instead of creating a duplicate' do
      existing = Spree::Address.create!(address_attributes.merge(user_id: user.id))

      expect do
        record.ship_address_attributes = address_attributes.merge(user_id: user.id)
      end.not_to change(Spree::Address, :count)

      expect(record.ship_address).to eq(existing)
    end

    it 'updates an editable saved address in place when an id is given' do
      saved = create(:address, user: user)

      record.ship_address_attributes = { id: saved.id, first_name: 'Renamed' }

      expect(record.ship_address.id).to eq(saved.id)
      expect(saved.reload.first_name).to eq('Renamed')
    end

    it 'promotes the address to the user default ship address' do
      record.ship_address_attributes = address_attributes

      expect(user.ship_address).to eq(record.ship_address)
    end

    it 'does not promote a quick-checkout wallet address to the user default' do
      record.ship_address_attributes = address_attributes.merge(quick_checkout: true)

      expect(user.ship_address).to be_nil
    end
  end

  describe '#bill_address_attributes=' do
    it 'promotes the address to the user default bill address' do
      record.bill_address_attributes = address_attributes

      expect(user.bill_address).to eq(record.bill_address)
    end
  end

  describe '#ship_address_id= / #bill_address_id=' do
    let(:own_address) { create(:address, user: user) }
    let(:foreign_address) { create(:address, user: create(:user)) }

    it 'accepts an address owned by the record user' do
      record.ship_address_id = own_address.id

      expect(record.ship_address_id).to eq(own_address.id)
    end

    it 'refuses an address owned by another user' do
      record.ship_address_id = foreign_address.id

      expect(record.ship_address_id).to be_nil
    end

    it 'refuses any address for a guest record' do
      guest_record.ship_address_id = own_address.id

      expect(guest_record.ship_address_id).to be_nil
    end
  end

  describe '#clone_shipping_address' do
    it 'copies the ship address onto the bill address and the user default' do
      ship_address = create(:address, user: user)
      record.ship_address = ship_address

      record.clone_shipping_address

      expect(record.bill_address).to eq(ship_address)
      expect(user.bill_address).to eq(ship_address)
    end
  end

  describe '#assign_default_addresses!' do
    let(:default_bill) { create(:address, user: user) }
    let(:default_ship) { create(:address, user: user) }

    before do
      user.update!(bill_address: default_bill, ship_address: default_ship)
    end

    it 'fills both addresses from the user defaults' do
      allow(record).to receive(:delivery_required?).and_return(true)

      record.assign_default_addresses!

      expect(record.bill_address.id).to eq(default_bill.id)
      expect(record.ship_address.id).to eq(default_ship.id)
    end

    it 'skips the ship address when no physical delivery is required' do
      allow(record).to receive(:delivery_required?).and_return(false)

      record.assign_default_addresses!

      expect(record.ship_address).to be_nil
    end
  end
end

RSpec.describe Spree::Purchase::AddressBook do
  context 'included in Spree::Cart' do
    let(:record) { create(:cart, store: store, customer: user, ship_address: nil, bill_address: nil) }
    let(:guest_record) { create(:cart, store: store, customer: nil) }

    it_behaves_like 'an address book host'
  end

  context 'included in Spree::Order' do
    let(:record) { create(:order, store: store, user: user, ship_address: nil, bill_address: nil) }
    let(:guest_record) { create(:order, store: store, user: nil, email: 'guest@example.com') }

    it_behaves_like 'an address book host'
  end
end
