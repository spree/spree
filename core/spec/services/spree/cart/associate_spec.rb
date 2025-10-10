require 'spec_helper'

module Spree
  describe Cart::Associate do
    subject { described_class.call(guest_order: order, user: user) }
    let(:user) { create(:user) }

    context 'when guest order is given' do
      let(:order) { create(:order, user: nil) }

      it 'assigns order to user' do
        expect(subject).to be_success
        expect(order.user).to eq(user)
      end
    end

    context 'when already assigned order is given' do
      let(:assigned_user) { create(:user) }
      let(:order) { create(:order, user: assigned_user) }

      it 'returns failure' do
        expect(subject).to be_failure
        expect(order.user).to eq(assigned_user)
      end
    end
  end
end
