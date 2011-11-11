require 'spec_helper'

describe "Shipments" do
  context "GET" do
    context "with an authorized api user" do
      context "retrieving a list of shipments" do
        before(:each) do
          2.times { Factory(:shipment) }
          @user = Factory(:admin_user)
          api_login(@user)
          get "/api/shipments", :format => :json
        end

        it_should_behave_like "status ok"

        it "should retrieve an array of 2 shipments" do
          page = JSON.load(last_response.body)
          page.map { |d| d['name'] }.length.should == 2.to_i
          page.first.keys.sort.should == ["shipment"]

          keys = ["address", "cost", "created_at", "id", "inventory_units", "number", "order_id", "shipped_at", "shipping_method", "state", "tracking", "updated_at"]
          page.first['shipment'].keys.sort.should == keys
        end
      end

      context "retrieving a specific shipment" do
        before(:each) do
          2.times { Factory(:shipment) }
          @user = Factory(:admin_user)
          api_login(@user)
          get "/api/shipments/#{Spree::Shipment.first.id}", :format => :json
        end

        it_should_behave_like "status ok"

        it "should return shipment information" do
          page = JSON.load(last_response.body)
          page['shipment']['address'].should  be_true
          page['shipment']['cost'].should  be_true
          page['shipment']['number'].should  be_true
          page['shipment']['shipping_method'].should  be_true
          page['shipment']['state'].should  be_true
          page['shipment']['tracking'].should  be_true
        end
      end
    end

    context "with an unauthorized user" do
      before(:each) do
        get "/api/shipments", :format => :json
      end

      it_should_behave_like "unauthorized"
    end
  end
end
