require 'spec_helper'

module Spree
  describe Checkout::Advance do
    subject { described_class.call(order: cart) }

    let(:store) { @default_store }
    let(:cart) { create(:cart_ready_for_delivery, store: store) }

    it 'recalculates the cart and returns success' do
      expect(subject).to be_success
      expect(subject.value).to eq(cart)
    end

    it 'proposes fulfillments when an address is present and none exist' do
      cart.fulfillments.destroy_all
      cart.reload

      expect(subject).to be_success
      expect(cart.reload.fulfillments).to be_present
    end

    context 'with shipping method selection' do
      let!(:other_method) do
        create(:shipping_method).tap do |delivery_method|
          delivery_method.calculator.preferred_amount = 33
          delivery_method.calculator.save!
        end
      end

      it 'selects the requested delivery method during advancement' do
        cart.rebuild_fulfillments!
        result = described_class.call(order: cart, shipping_method_id: other_method.id)

        expect(result).to be_success
        expect(cart.reload.fulfillments.first.delivery_method&.id).to eq(other_method.id)
      end
    end

    it 'keeps completion out of scope — advancing never completes the cart' do
      expect(subject).to be_success
      expect(cart.reload.completed_at).to be_nil
    end
  end
end
