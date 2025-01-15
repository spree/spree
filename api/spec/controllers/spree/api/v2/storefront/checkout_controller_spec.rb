require 'spec_helper'

RSpec.describe Spree::Api::V2::Storefront::CheckoutController do
  before do
    allow(controller).to receive(:spree_current_order).and_return(order)
    allow(controller).to receive(:spree_authorize!).and_return(true)
  end

  describe '#select_shipping_method' do
    subject(:select_shipping_method) { patch :select_shipping_method, params: { shipping_method_id: shipping_method.id } }

    let!(:order) { create(:order_with_line_items) }
    let!(:shipping_rate) { create(:shipping_rate, shipment: shipment, shipping_method: shipping_method) }

    let(:shipment) { order.shipments.first }
    let(:shipping_method) { create(:shipping_method, name: 'Worldwide') }

    it 'selects a new shipping method' do
      select_shipping_method

      expect(shipment.reload.shipping_method).to eq(shipping_method)
    end

    it 'updates the order totals' do
      expect { select_shipping_method }.
        to change { order.total }.from(110).to(20).and(
          change { order.shipment_total }.from(100).to(10)
        )
    end
  end

  describe '#advance' do
    context 'on a quick checkout' do
      subject(:advance) { patch :advance, params: { shipping_method_id: shipping_method_2.id } }

      let!(:order) { create(:order_with_line_items, state: :address, payments: [create(:payment)]) }
      let!(:shipping_rate_1) { create(:shipping_rate, shipment: shipment, selected: true, shipping_method: shipping_method_1, cost: 0) }
      let!(:shipping_rate_2) { create(:shipping_rate, shipment: shipment, selected: false, shipping_method: shipping_method_2, cost: 20) }

      let(:shipment) { order.shipments.first }
      let(:shipping_method_1) { create(:shipping_method, name: 'Standard') }
      let(:shipping_method_2) { create(:shipping_method, name: 'Express') }

      before do
        allow(controller).to receive(:check_if_quick_checkout).and_return(true)
      end

      it 'advances with a new shipping method' do
        advance

        expect(response.status).to eq(200)
        expect(order.reload.shipping_method.id).to eq(shipping_method_2.id)
      end
    end
  end

  describe '#validate_order_for_payment' do
    subject { post :validate_order_for_payment, params: params }

    let(:params) { {} }

    context 'when state changed back from payment' do
      let!(:order) { create(:order_with_line_items, state: :delivery, payments: [create(:payment)]) }

      it 'responds with an error' do
        subject

        expect(response.status).to eq(422)
        expect(json_response.dig(:meta, :messages)).to contain_exactly(Spree.t(:cart_state_changed))
      end
    end

    context 'when order items went out of stock' do
      let(:params) { { skip_state: true } }

      let!(:order) { create(:order_with_line_items, state: :payment, payments: [create(:payment)], line_items_count: 2) }

      let(:line_item_1) { order.line_items[0] }
      let(:line_item_2) { order.line_items[1] }

      before do
        line_item_1.variant.stock_items.update_all(count_on_hand: 0, backorderable: false)
        line_item_2.variant.stock_items.update_all(count_on_hand: 10, backorderable: false)
      end

      it 'responds with an error' do
        subject

        expect(response.status).to eq(422)
        expect(json_response.dig(:meta, :messages)).to contain_exactly(Spree.t('cart_line_item.out_of_stock', li_name: line_item_1.name))
      end
    end

    context 'when order items were discontinued' do
      let(:params) { { skip_state: true } }

      let!(:order) { create(:order_with_line_items, state: :payment, payments: [create(:payment)], line_items_count: 2) }

      let(:line_item_1) { order.line_items[0] }
      let(:line_item_2) { order.line_items[1] }

      before do
        line_item_1.variant.update!(discontinue_on: 1.hour.ago)
      end

      it 'responds with an error' do
        subject

        expect(response.status).to eq(422)
        expect(json_response.dig(:meta, :messages)).to contain_exactly(Spree.t('cart_line_item.discontinued', li_name: line_item_1.name))
      end
    end
  end
end
