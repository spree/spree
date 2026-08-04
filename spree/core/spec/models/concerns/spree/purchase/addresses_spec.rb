require 'spec_helper'

# Shared battery for Spree::Purchase::Addresses, run against BOTH hosts.
# Checkout moved from Order to Cart once already and silently lost this
# behavior (dedup, default promotion, ownership guard) — the shared examples
# exist so it cannot happen again without a red suite.
RSpec.shared_examples 'an addresses host' do
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
      record.assign_default_addresses!

      expect(record.bill_address.id).to eq(default_bill.id)
      expect(record.ship_address.id).to eq(default_ship.id)
    end

    it 'skips the ship address for an all-digital record' do
      allow(record).to receive(:digital?).and_return(true)

      record.assign_default_addresses!

      expect(record.ship_address).to be_nil
    end

    it 'still assigns the ship address to an empty record — items usually arrive after the address' do
      record.assign_default_addresses!

      expect(record.ship_address).to be_present
    end
  end

  describe '#shipping_address_required?' do
    let(:shipping_method) { instance_double(Spree::DeliveryMethod, requires_address?: true) }
    let(:pickup_method) { instance_double(Spree::DeliveryMethod, requires_address?: false) }

    def fulfillment_with(delivery_method)
      instance_double(Spree::Fulfillment, delivery_method: delivery_method)
    end

    context 'with delivery methods selected' do
      it 'is false when every selected method delivers without an address' do
        allow(record).to receive(:fulfillments).and_return([fulfillment_with(pickup_method)])

        expect(record.shipping_address_required?).to be false
      end

      it 'is true when any selected method requires one' do
        allow(record).to receive(:fulfillments)
          .and_return([fulfillment_with(pickup_method), fulfillment_with(shipping_method)])

        expect(record.shipping_address_required?).to be true
      end
    end

    context 'before any selection' do
      let!(:store_shipping_method) { create(:delivery_method, store: store) }

      it 'is false for an empty record' do
        expect(record.shipping_address_required?).to be false
      end

      it 'is true when an item can only be fulfilled by an address-requiring type' do
        create(:line_item, "#{record.model_name.element}": record)

        expect(record.reload.shipping_address_required?).to be true
      end

      it 'is false when merchant pickup intent is expressed' do
        create(:line_item, "#{record.model_name.element}": record)
        record.preferred_stock_location_id = create(:stock_location, pickup_enabled: true).id

        expect(record.shipping_address_required?).to be false
      end

      it 'is false when every item is deliverable only by address-free types' do
        digital_type = create(:product_type, fulfillment_types: ['digital'])
        product = create(:product, product_type: digital_type, store: store)
        create(:line_item, "#{record.model_name.element}": record, variant: product.default_variant)

        expect(record.reload.shipping_address_required?).to be false
      end
    end
  end

  describe '#shipping_eq_billing_address?' do
    it 'compares the two addresses' do
      address = create(:address, user: user)
      record.ship_address = address
      record.bill_address = address
      expect(record.shipping_eq_billing_address?).to be(true)

      record.bill_address = create(:address, user: user)
      expect(record.shipping_eq_billing_address?).to be(false)
    end
  end

  describe 'mass attribute assignment for bill_address_id, ship_address_id' do
    let(:address) { create(:address, user: user) }

    it 'is able to mass assign bill_address_id' do
      record.update(bill_address_id: address.id)
      expect(record.bill_address_id).to eq address.id
    end

    it 'is able to mass assign ship_address_id' do
      record.update(ship_address_id: address.id)
      expect(record.ship_address_id).to eq address.id
    end
  end

  describe 'same bill & ship addresses' do
    it 'has equal ids when both ids are set' do
      address = create(:address, user: user)
      record.update!(bill_address_id: address.id, ship_address_id: address.id)

      expect(record.bill_address_id).to eq record.ship_address_id
    end
  end

  describe 'editing an address locked by a completed order' do
    let(:address) { create(:address, user: user) }
    let!(:completed_order) { create(:completed_order_with_totals, user: user, ship_address: address) }

    it 'creates a new address with the updated attributes' do
      expect(
        record.update(
          bill_address_attributes: {
            firstname: 'New name',
            **address.attributes.except(
              'firstname', 'created_at', 'updated_at', 'deleted_at', 'quick_checkout',
              'public_metadata', 'private_metadata', 'latitude', 'longitude', 'preferences'
            )
          }
        )
      ).to be_truthy

      expect(record.bill_address_id).not_to eq address.id
      expect(record.bill_address.firstname).to eq 'New name'
    end
  end
end

RSpec.describe Spree::Purchase::Addresses do
  let(:store) { @default_store }
  let(:user) { create(:user) }

  context 'included in Spree::Cart' do
    let(:record) { create(:cart, store: store, customer: user, ship_address: nil, bill_address: nil) }
    let(:guest_record) { create(:cart, store: store, customer: nil) }

    it_behaves_like 'an addresses host'

    # Carts expose only use_shipping through the API — the ship→bill clone
    # is the one wired as a callback.
    describe 'use_shipping clone callback' do
      it 'clones the ship address onto the bill address when truthy' do
        record.ship_address = create(:address, user: user)
        record.use_shipping = true
        record.valid?

        expect(record.bill_address).to eq(record.ship_address)
      end
    end
  end

  context 'included in Spree::Order' do
    let(:record) { create(:order, store: store, user: user, ship_address: nil, bill_address: nil) }
    let(:guest_record) { create(:order, store: store, user: nil, email: 'guest@example.com') }

    it_behaves_like 'an addresses host'

    describe 'use_billing clone callback (deprecated bridge, removed in 6.1)' do
      let(:order) { build(:order) }

      before do
        order.bill_address = create(:address)
        order.ship_address = nil
      end

      %w[true 1].push(true).each do |truthy_value|
        context "with #{truthy_value.inspect}" do
          before { order.use_billing = truthy_value }

          it 'clones the bill address to the ship address' do
            order.valid?
            expect(order.ship_address).to eq(order.bill_address)
          end
        end
      end

      context "with something other than a 'truthful' value" do
        before { order.use_billing = '0' }

        it 'does not clone the bill address to the shipping' do
          order.valid?
          expect(order.ship_address).to be_nil
        end
      end

      it 'has equal ids when use_billing is active at create' do
        address = create(:address)
        order = create(:order, use_billing: true, bill_address_id: address.id, ship_address_id: nil).reload

        expect(order.bill_address_id).to eq order.ship_address_id
      end
    end
  end
end
