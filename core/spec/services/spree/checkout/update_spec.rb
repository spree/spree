require 'spec_helper'

describe Spree::Checkout::Update, type: :service do
  describe '#transform_address_params' do
    let!(:state)              { create(:state) }
    let!(:country)            { state.country }
    let!(:replace_country)    { described_class.new }
    let!(:address) do
      {
        firstname: 'John',
        lastname: 'Doe',
        address1: '7735 Old Georgetown Road',
        city: 'Bethesda',
        phone: '3014445002',
        zipcode: '20814',
        state_id: state.id,
        country_iso: country.iso
      }
    end

    context 'with ship_address order params' do
      let(:order_params) do
        ActionController::Parameters.new(
          order: {
            ship_address_attributes: address
          }
        )
      end
      let(:result) { replace_country.send(:replace_country_iso_with_id, order_params, 'ship') }

      before { result }

      it 'will return hash contain country_id' do
        expect(result[:order][:ship_address_attributes][:country_id]).to eq country.id
      end

      it 'will return hash without country_iso' do
        expect(result[:order][:ship_address_attributes]).not_to include(:country_iso)
      end
    end

    context 'with bill_address order params' do
      let(:order_params) do
        ActionController::Parameters.new(
          order: {
            bill_address_attributes: address
          }
        )
      end
      let(:result) { replace_country.send(:replace_country_iso_with_id, order_params, 'bill') }

      before { result }

      it 'will return hash contain country_id' do
        expect(result[:order][:bill_address_attributes][:country_id]).to eq country.id
      end

      it 'will return hash without country_iso' do
        expect(result[:order][:bill_address_attributes]).not_to include(:country_iso)
      end
    end
  end

  describe 'update address' do
    let(:order) { create(:order_with_line_items) }
    let(:state) { create(:state) }
    let(:country) { state.country }
    let(:update_service) { described_class.new }
    let(:address) do
      {
        firstname: 'John',
        lastname: 'Doe',
        address1: '7735 Old Georgetown Road',
        city: 'Bethesda',
        phone: '3014445002',
        zipcode: '20814',
        state_id: state.id,
        country_iso: country.iso
      }
    end
    let(:order_params) do
      ActionController::Parameters.new(
        order: {
          ship_address_attributes: address
        }
      )
    end
    let(:permitted_attributes) do
      Spree::PermittedAttributes.checkout_attributes + [
        bill_address_attributes: Spree::PermittedAttributes.address_attributes,
        ship_address_attributes: Spree::PermittedAttributes.address_attributes
      ]
    end

    it 'should set order back to address state' do
      expect(order.state).not_to eq 'address'
      expect(order.ship_address.state.id).not_to eq state.id

      update_service.send(:call, order: order, params: order_params, permitted_attributes: permitted_attributes, request_env: nil)

      expect(order.state).to eq 'address'
      expect(order.ship_address.state.id).to eq state.id
    end
  end

  describe 'update selected shipping rate' do
    let(:update_service) { described_class.new }
    let(:order) { create(:order_with_line_items) }
    let(:order_params) do
      ActionController::Parameters.new(
        order: {
          shipments_attributes: [
            {
              id: order.shipments.first.id,
              selected_shipping_rate_id: order.shipments.first.shipping_rates.first.id
            }
          ]
        }
      )
    end
    let(:permitted_attributes) do
      Spree::PermittedAttributes.checkout_attributes + [
        shipments_attributes: Spree::PermittedAttributes.shipment_attributes
      ]
    end

    it 'should set order back to delivery state' do
      expect(order.state).not_to eq 'delivery'

      update_service.send(:call, order: order, params: order_params, permitted_attributes: permitted_attributes, request_env: nil)

      expect(order.state).to eq 'delivery'
    end
  end
end
