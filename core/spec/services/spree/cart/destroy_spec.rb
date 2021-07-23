require 'spec_helper'

module Spree
  describe Cart::Destroy do
    subject { described_class.call order: order }

    let(:order) { Spree::Order.create(email: 'test@example.com') }

    before { Spree::Dependencies.cart_empty_service.constantize.call(order: order) }

    it 'destroys the order' do
      subject

      expect(order.destroyed?).to be true
    end
  end
end
