require 'spec_helper'

module Spree
  describe Api::InventoryUnitsController do
    render_views

    before do
      stub_authentication!
      @inventory_unit = create(:inventory_unit)
    end

    context "as an admin" do
      sign_in_as_admin!

      it "gets an inventory unit" do
        api_get :show, :id => @inventory_unit.id
        json_response['state'].should eq @inventory_unit.state
      end

      it "updates an inventory unit (only shipment is accessable by default)" do
        api_put :update, :id => @inventory_unit.id,
                         :inventory_unit => { :shipment => nil }
        json_response['shipment_id'].should be_nil
      end

      context 'fires state event' do
        it 'if supplied with :fire param' do
          api_put :update, :id => @inventory_unit.id,
                           :fire => 'ship',
                           :inventory_unit => { :shipment => nil }

          json_response['state'].should eq 'shipped'
        end

        it 'and returns exception if cannot fire' do
          api_put :update, :id => @inventory_unit.id,
                           :fire => 'return'
          json_response['exception'].should match /cannot transition to return/
        end

        it 'and returns exception bad state' do
          api_put :update, :id => @inventory_unit.id,
                           :fire => 'bad'
          json_response['exception'].should match /cannot transition to bad/
        end
      end
    end
  end
end
