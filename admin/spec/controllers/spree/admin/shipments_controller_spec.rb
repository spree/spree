require 'spec_helper'

RSpec.describe Spree::Admin::ShipmentsController, type: :controller do
  stub_authorization!
  render_views

  let(:order) { create(:order_ready_to_ship) }
  let(:shipment) { order.shipments.first }
  let(:other_shipping_method) { create(:shipping_rate, shipment: shipment) }
  let(:shipment_params) { { tracking: '12345', selected_shipping_rate_id: other_shipping_method.id } }

  describe 'PUT #update' do
    context 'when update is successful' do
      before do
        put :update, params: { order_id: order.number, id: shipment.number, shipment: shipment_params }
      end

      it 'updates shipment' do
        expect(flash[:success]).to eq(Spree.t(:successfully_updated, resource: Spree.t(:shipment)))

        shipment.reload
        expect(shipment.tracking).to eq '12345'
        expect(shipment.selected_shipping_rate_id).to eq other_shipping_method.id
      end

      it 'redirects to the edit order page' do
        expect(response).to redirect_to(spree.edit_admin_order_path(order))
      end
    end
  end

  describe '#ship' do
    context 'when shipment can be shipped' do
      before do
        shipment.update(tracking: '1234567890')
        expect(shipment.tracking).to eq('1234567890')
      end

      it 'ships the shipment' do
        post :ship, params: { order_id: order.number, id: shipment.number }
        expect(shipment.reload.state).to eq('shipped')
      end
    end

    context 'when shipment cannot be shipped' do
      before do
        shipment.update(tracking: nil)
        expect(shipment.tracking).to be_nil
      end

      it 'flashes error' do
        post :ship, params: { order_id: order.number, id: shipment.number }
        expect(flash[:error]).to eq(Spree.t(:cannot_ship))
      end
    end
  end
end
