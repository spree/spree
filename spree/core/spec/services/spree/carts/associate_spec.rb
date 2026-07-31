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
