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
      let(:result) { replace_country.send(:replace_country_iso_with_id, order_params[:order][:ship_address_attributes]) }

      before { result }

      it 'will return hash contain country_id' do
        expect(result[:country_id]).to eq country.id
      end

      it 'will return hash without country_iso' do
        expect(result).not_to include(:country_iso)
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
      let(:result) { replace_country.send(:replace_country_iso_with_id, order_params[:order][:bill_address_attributes]) }

      before { result }

      it 'will return hash contain country_id' do
        expect(result[:country_id]).to eq country.id
      end

      it 'will return hash without country_iso' do
        expect(result).not_to include(:country_iso)
      end
    end
  end

  describe 'update address' do
    let(:user) { create(:user_with_addresses) }
    let(:order) { create(:order_with_line_items, user: user, bill_address: user.bill_address, ship_address: user.ship_address, state: order_state) }
    let(:state) { create(:state) }
    let(:country) { state.country }
    let(:update_service) { described_class.call(order: order, params: order_params, permitted_attributes: permitted_attributes, request_env: nil) }
    let(:order_params) { ActionController::Parameters.new(order: {
                                                                  ship_address_id: ship_address_id,
                                                                  bill_address_id: bill_address_id,
                                                                  ship_address_attributes: address_attributes
                                                                 }) }
    let(:permitted_attributes) do
      Spree::PermittedAttributes.checkout_attributes + [
        bill_address_attributes: Spree::PermittedAttributes.address_attributes,
        ship_address_attributes: Spree::PermittedAttributes.address_attributes
      ]
    end

    context 'at cart state' do
      let(:order_state) { 'cart' }
      let(:ship_address_id) { nil }
      let(:bill_address_id) { nil }
      let(:address_attributes) do
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

      it 'should set order back to address state' do
        expect(order.state).not_to eq 'address'
        expect(order.ship_address.state.id).not_to eq state.id

        update_service

        expect(order.state).to eq 'address'
        expect(order.ship_address.state.id).to eq state.id
      end
    end

    context 'at address state' do
      let(:order_state) { 'address' }
      let(:ship_address_id) { order.ship_address_id }
      let(:bill_address_id) { order.bill_address_id }
      let(:address_attributes) { nil }
      let(:address) { create(:address, user: user) }

      shared_examples 'user default addresses did not change' do
        it 'does not change user default addresses' do
          update_service

          expect(user.reload.bill_address_id).not_to eq order.reload.bill_address
          expect(user.reload.bill_address_id).not_to eq order.reload.ship_address
          expect(user.reload.ship_address_id).not_to eq order.reload.bill_address
          expect(user.reload.ship_address_id).not_to eq order.reload.ship_address
        end
      end

      shared_examples 'checkout is in address step' do
        it 'keeps checkout in address step' do
          update_service

          expect(order.reload.state).to eq 'address'
        end
      end

      context 'when address did not change' do
        it_behaves_like 'user default addresses did not change'
        it_behaves_like 'checkout is in address step'

        it 'does not change order addresses' do
          expect(update_service).to be_success

          expect(order.reload.bill_address_id).to eq user.bill_address_id
          expect(order.reload.ship_address_id).to eq user.ship_address_id
        end
      end

      context 'when ship address changed' do
        let(:ship_address_id) { address.id }

        it_behaves_like 'user default addresses did not change'
        it_behaves_like 'checkout is in address step'

        it 'should update order ship address' do
          expect(update_service).to be_success
          expect(order.reload.bill_address_id).to eq user.bill_address_id
          expect(order.reload.ship_address_id).to eq address.id
        end
      end

      context 'when bill address changed' do
        let(:bill_address_id) { address.id }

        it_behaves_like 'user default addresses did not change'
        it_behaves_like 'checkout is in address step'

        it 'should update order bill address' do
          expect(update_service).to be_success
          expect(order.reload.bill_address_id).to eq address.id
          expect(order.reload.ship_address_id).to eq user.ship_address_id
        end
      end

      context 'when ship and bill address changed' do
        let(:ship_address_id) { address.id }
        let(:bill_address_id) { address.id }

        it_behaves_like 'user default addresses did not change'
        it_behaves_like 'checkout is in address step'

        it 'should update both order addresses' do
          expect(update_service).to be_success
          expect(order.reload.bill_address_id).to eq address.id
          expect(order.reload.ship_address_id).to eq address.id
        end
      end
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
