require 'spec_helper'

describe "Orders" do
  context "GET" do
    context "with an authorized api user" do
      context "retreiving all orders" do
        before(:each) do
          5.times { Factory(:order) }
          @user = Factory(:admin_user)
          api_login(@user)
          get "/api/orders", :format => :json
        end

        it_should_behave_like "status ok"

        it "should return an array with 5 orders" do
          page = JSON.load(last_response.body)
          page.map { |d| d['name'] }.length.should == 5.to_i
          page.first.keys.sort.should == ["order"]

          keys = ["adjustment_total", "bill_address_id", "completed_at", "created_at", "credit_total", "email",
            "id", "item_total", "number", "payment_state", "payment_total", "ship_address_id", "shipment_state",
            "shipping_method_id", "special_instructions", "state", "total", "updated_at", "user_id"]

          page.first['order'].keys.sort.should == keys
        end
      end

      context "retrieving a specific order" do
        before(:each) do
          2.times { Factory(:order) }
          @user = Factory(:admin_user)
          api_login(@user)
          get "/api/orders/#{Spree::Order.first.id}", :format => :json
        end

        it_should_behave_like "status ok"

        it "should return order information" do
          page = JSON.load(last_response.body)
          page['order']['number'].should  be_true
          page['order']['state'].should  be_true
          page['order']['email'].should  be_true
          page['order']['credit_total'].should  be_true
        end
      end
    end

    context "with an unauthorized user" do
      before(:each) do
        2.times { Factory(:order) }
        get "/api/orders", :format => :json
      end

      it_should_behave_like "unauthorized"
    end
  end
end
