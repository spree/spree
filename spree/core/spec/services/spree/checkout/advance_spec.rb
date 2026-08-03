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

    it 'proposes fulfillments for a pure-pickup cart with no shipping address' do
      pickup_location = create(:stock_location, pickup_enabled: true, pickup_stock_policy: 'any', store: store)
      create(:pickup_delivery_method, store: store)
      pickup_capable_type = create(:product_type, fulfillment_types: %w[shipping pickup])

      cart.fulfillments.destroy_all
      cart.update!(ship_address: nil, preferred_stock_location_id: pickup_location.id)
      cart.line_items.each { |line_item| line_item.variant.product.update!(product_type: pickup_capable_type) }
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
