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
        put :update, params: { order_id: order.to_param, id: shipment.to_param, shipment: shipment_params }
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
        post :ship, params: { order_id: order.to_param, id: shipment.to_param }
        expect(shipment.reload.state).to eq('shipped')
      end
    end

    context 'when shipment cannot be shipped' do
      before do
        shipment.update(tracking: nil)
        expect(shipment.tracking).to be_nil
      end

      it 'flashes error' do
        post :ship, params: { order_id: order.to_param, id: shipment.to_param }
        expect(flash[:error]).to eq(Spree.t(:cannot_ship))
      end
    end
  end

  describe 'GET #split' do
    let(:variant) { shipment.inventory_units.first.variant }

    it 'assigns the variant and calculates max quantity' do
      get :split, params: { order_id: order.to_param, id: shipment.to_param, variant_id: variant.to_param }
      expect(response).to be_successful
      expect(assigns(:variant)).to eq(variant)
      expect(assigns(:max_quantity)).to eq(shipment.inventory_units.where(variant_id: variant.id).sum(:quantity))
    end
  end

  describe 'POST #transfer' do
    let(:variant) { shipment.inventory_units.first.variant }
    let(:stock_location) { shipment.stock_location }

    context 'to a new stock location' do
      let(:destination_stock_location) { create(:stock_location) }

      it 'builds a FulfilmentChanger with the destination location and runs it' do
        fulfilment_changer = instance_double(Spree::FulfilmentChanger, valid?: true, run!: true)
        expect(Spree::FulfilmentChanger).to receive(:new).with(
          satisfy { |params|
            params[:current_stock_location] == stock_location &&
              params[:desired_stock_location] == destination_stock_location &&
              params[:current_shipment] == shipment &&
              params[:desired_shipment].is_a?(Spree::Shipment) &&
              params[:desired_shipment].new_record? &&
              params[:desired_shipment].stock_location == destination_stock_location &&
              params[:variant] == variant &&
              params[:quantity] == 1
          }
        ).and_return(fulfilment_changer)

        post :transfer, params: {
          order_id: order.to_param,
          id: shipment.to_param,
          variant_id: variant.to_param,
          destination: "stock-location_#{destination_stock_location.id}",
          quantity: 1
        }

        expect(flash[:success]).to eq(Spree.t(:shipment_transfer_success))
      end
    end

    context 'to an existing shipment' do
      let(:destination_shipment) { create(:shipment, order: order, stock_location: stock_location) }

      it 'builds a FulfilmentChanger with the destination shipment and runs it' do
        fulfilment_changer = instance_double(Spree::FulfilmentChanger, valid?: true, run!: true)
        expect(Spree::FulfilmentChanger).to receive(:new).with(
          current_stock_location: stock_location,
          desired_stock_location: stock_location,
          current_shipment: shipment,
          desired_shipment: destination_shipment,
          variant: variant,
          quantity: 1
        ).and_return(fulfilment_changer)

        post :transfer, params: {
          order_id: order.to_param,
          id: shipment.to_param,
          variant_id: variant.to_param,
          destination: "shipment_#{destination_shipment.id}",
          quantity: 1
        }

        expect(flash[:success]).to eq(Spree.t(:shipment_transfer_success))
      end
    end

    context 'with invalid quantity' do
      it 'flashes an error and does not move inventory' do
        expect {
          post :transfer, params: {
            order_id: order.to_param,
            id: shipment.to_param,
            variant_id: variant.to_param,
            destination: "stock-location_#{stock_location.id}",
            quantity: 0
          }
        }.not_to change { order.shipments.count }

        expect(flash[:error]).to be_present
      end
    end

    context 'with invalid destination' do
      it 'flashes an error and does not move inventory' do
        expect {
          post :transfer, params: {
            order_id: order.to_param,
            id: shipment.to_param,
            variant_id: variant.to_param,
            destination: 'invalid_destination',
            quantity: 1
          }
        }.not_to change { order.shipments.count }

        expect(flash[:error]).to include(Spree.t('admin.shipment_transfer.wrong_destination'))
      end
    end
  end
end
