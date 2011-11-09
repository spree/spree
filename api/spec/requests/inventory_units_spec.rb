require 'spec_helper'

describe "Inventory Units" do
  context "GET" do
    context "with an authorized api user" do
      context "retreiving all inventory units" do
        before(:each) do
          2.times { Factory(:inventory_unit) }
          @user = Factory(:admin_user)
          api_login(@user)
          get "/api/inventory_units", :format => :json
        end

        it_should_behave_like "status ok"

        it "should return an array with 2 inventory units" do
          page = JSON.load(last_response.body)
          page.map { |d| d['name'] }.length.should == 2.to_i
          page.first.keys.sort.should == ["inventory_unit"]

          keys = ["created_at", "id", "lock_version", "order_id", "return_authorization_id", "shipment_id", "state", "updated_at", "variant_id"]
          page.first['inventory_unit'].keys.sort.should == keys
        end
      end

      context "retrieving a specific inventory unit" do
        before(:each) do
          2.times { Factory(:inventory_unit) }
          @user = Factory(:admin_user)
          api_login(@user)
          get "/api/inventory_units/#{Spree::InventoryUnit.first.id}", :format => :json
        end

        it_should_behave_like "status ok"

        it "should return inventory unit information" do
          page = JSON.load(last_response.body)
          page['inventory_unit']['lock_version'].should be_true
          page['inventory_unit']['state'].should be_true
        end
      end
    end

    context "with an unauthorized user" do
      before(:each) do
        2.times { Factory(:inventory_unit) }
        get "/api/inventory_units/#{Spree::InventoryUnit.first.id}", :format => :json
      end

      it_should_behave_like "unauthorized"
    end
  end
end
