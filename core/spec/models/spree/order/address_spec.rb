require 'spec_helper'

describe Spree::Order, type: :model do
  let(:order) { Spree::Order.new }

  context 'validation' do
    context 'when @use_billing is populated' do
      before do
        order.bill_address = create(:address)
        order.ship_address = nil
      end

      context 'with true' do
        before { order.use_billing = true }

        it 'clones the bill address to the ship address' do
          order.valid?
          expect(order.ship_address).to eq(order.bill_address)
        end
      end

      context "with 'true'" do
        before { order.use_billing = 'true' }

        it 'clones the bill address to the shipping' do
          order.valid?
          expect(order.ship_address).to eq(order.bill_address)
        end
      end

      context "with '1'" do
        before { order.use_billing = '1' }

        it 'clones the bill address to the shipping' do
          order.valid?
          expect(order.ship_address).to eq(order.bill_address)
        end
      end

      context "with something other than a 'truthful' value" do
        before { order.use_billing = '0' }

        it 'does not clone the bill address to the shipping' do
          order.valid?
          expect(order.ship_address).to be_nil
        end
      end
    end
  end

  context 'address book' do
    let(:order) { create(:order) }
    let(:address) { create(:address, user: order.user) }

    describe 'mass attribute assignment for bill_address_id, ship_address_id' do
      it 'is able to mass assign bill_address_id' do
        params = { bill_address_id: address.id }
        order.update(params)
        expect(order.bill_address_id).to eq address.id
      end

      it 'is able to mass assign ship_address_id' do
        params = { ship_address_id: address.id }
        order.update(params)
        expect(order.ship_address_id).to eq address.id
      end
    end

    describe 'Create order with the same bill & ship addresses' do
      it 'has equal ids when set ids' do
        address = create(:address)
        @order = create(:order, bill_address_id: address.id, ship_address_id: address.id)
        expect(@bill_address_id).to eq @order.ship_address_id
      end

      it 'has equal ids when option use_billing is active' do
        address = create(:address)
        @order  = create(:order, use_billing: true,
                                 bill_address_id: address.id,
                                 ship_address_id: nil)
        @order = @order.reload
        expect(@order.bill_address_id).to eq @order.ship_address_id
      end
    end

    context 'when user wants to update firstname of the address with already completed order' do
      let(:address) { create(:address, user: order.user) }
      let!(:completed_order) { create(:completed_order_with_totals, user: order.user, ship_address: address) }

      it 'creates new address with updated attributes' do
        expect(
          order.update(
                 bill_address_attributes: {
                   firstname: 'New name',
                   **address.attributes.except(
                     'firstname',
                     'created_at',
                     'updated_at',
                     'deleted_at',
                     'quick_checkout',
                     'public_metadata',
                     'private_metadata',
                     'latitude',
                     'longitude',
                     'preferences'
                   )
                 }
               )
        ).to be_truthy

        expect(order.bill_address_id).not_to eq address.id
        expect(order.bill_address.firstname).to eq 'New name'
      end
    end
  end
end
