require 'spec_helper'

module Spree
  describe Api::V1::InventoryUnitsController, type: :controller do
    render_views

    before do
      stub_authentication!
      @inventory_unit = create(:inventory_unit)
    end

    context 'as an admin' do
      sign_in_as_admin!

      it 'gets an inventory unit' do
        api_get :show, id: @inventory_unit.id
        expect(json_response['state']).to eq @inventory_unit.state
      end

      it 'updates an inventory unit' do
        api_put :update, id: @inventory_unit.id,
                         inventory_unit: { shipment_id: nil }
        expect(json_response['shipment_id']).to be_nil
      end

      context 'fires state event' do
        it 'if supplied with :fire param' do
          api_put :update, id: @inventory_unit.id,
                           fire: 'ship',
                           inventory_unit: { shipment: { tracking: 'foobar' } }
          expect(json_response['state']).to eq 'shipped'
        end

        it 'and returns exception if cannot fire' do
          api_put :update, id: @inventory_unit.id,
                           fire: 'return'
          expect(json_response['exception']).to match(/cannot transition to return/)
        end

        it 'and returns exception bad state' do
          api_put :update, id: @inventory_unit.id,
                           fire: 'bad'
          expect(json_response['exception']).to match(/cannot transition to bad/)
        end
      end
    end
  end
end
