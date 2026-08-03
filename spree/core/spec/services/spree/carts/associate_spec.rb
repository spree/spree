require 'spec_helper'

module Spree
  describe Carts::Associate do
    subject { described_class.call(guest_cart: cart, user: user) }

    let(:user) { create(:user) }

    context 'when a guest cart is given' do
      let(:cart) { create(:cart, customer: nil) }

      it 'assigns the cart to the user and takes over the email' do
        expect(subject).to be_success
        expect(cart.reload.customer).to eq(user)
        expect(cart.email).to eq(user.email)
      end

      it 'copies valid saved default addresses, gated on physical delivery' do
        user.update!(bill_address: create(:address, user: user), ship_address: create(:address, user: user))
        cart_with_items = create(:cart_with_line_items, customer: nil)

        described_class.call(guest_cart: cart_with_items, user: user)

        expect(cart_with_items.reload.bill_address_id).to eq(user.bill_address_id)
        expect(cart_with_items.ship_address_id).to eq(user.ship_address_id)
      end

      it 'never copies an invalid saved default address' do
        invalid_address = build(:address, city: nil)
        invalid_address.save(validate: false)
        user.update_columns(bill_address_id: invalid_address.id)

        expect(subject).to be_success
        expect(cart.reload.bill_address_id).to be_nil
      end

      it 'skips the ship address when no physical delivery is required' do
        user.update!(ship_address: create(:address, user: user))

        expect(subject).to be_success
        expect(cart.reload.ship_address_id).to be_nil
      end
    end

    context 'when an already assigned cart is given' do
      let(:assigned_user) { create(:user) }
      let(:cart) { create(:cart, customer: assigned_user) }

      it 'reassigns the cart to the new user' do
        expect(subject).to be_success
        expect(cart.reload.customer).to eq(user)
      end

      context 'with guest_only: true' do
        subject { described_class.call(guest_cart: cart, user: user, guest_only: true) }

        it 'returns failure' do
          expect(subject).to be_failure
          expect(cart.reload.customer).to eq(assigned_user)
        end
      end
    end
  end
end
