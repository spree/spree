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

    # A saved address copied onto the cart at sign-in builds no delivery, so
    # free shipping the cart already qualifies for first has something to cover here.
    it 'applies an automatic free-shipping promotion once it proposes the first delivery' do
      create(:free_shipping_promotion, store: store, kind: :automatic, code: nil)
      cart.fulfillments.destroy_all
      cart.recalculate_totals!
      cart.reload

      expect(subject).to be_success

      cart.reload
      expect(cart.delivery_total).to be_positive
      expect(cart.discount_total).to eq(-cart.delivery_total)
      expect(cart.total).to eq(cart.item_total)
    end

    it 'proposes fulfillments for a pure-pickup cart with no shipping address' do
      pickup_location = create(:stock_location, pickup_enabled: true, pickup_stock_policy: 'any', store: store)
      create(:pickup_delivery_method, store: store)

      cart.fulfillments.destroy_all
      cart.update!(ship_address: nil, preferred_stock_location_id: pickup_location.id)
      cart.reload

      expect(subject).to be_success
      expect(cart.reload.fulfillments).to be_present
    end

    context 'with shipping method selection' do
      let!(:other_method) do
        create(:delivery_method).tap do |delivery_method|
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
