require 'spec_helper'

describe "Line Items" do
  context "GET" do
    context "with an authorized api user" do
      context "retreiving all inventory units" do
        before(:each) do
          line_item1 = Factory(:line_item)
          Factory(:line_item, :order => line_item1.order)
          @user = Factory(:admin_user)
          api_login(@user)
          line_item = Spree::LineItem.last
          get "/api/orders/#{line_item.order.id}/line_items", :format => :json
        end

        it_should_behave_like "status ok"

        it "should return an array with 2 line items" do
          page = JSON.load(last_response.body)
          page.map { |d| d['name'] }.length.should == 2.to_i
          page.first.keys.sort.should == ["line_item"]

          keys =  ["created_at", "description", "id", "order_id", "price", "quantity", "updated_at", "variant", "variant_id"]
          page.first['line_item'].keys.sort.should == keys
        end
      end

      context "retrieving a specific inventory unit" do
        before(:each) do
          2.times { Factory(:line_item) }
          @user = Factory(:admin_user)
          api_login(@user)
          line_item = Spree::LineItem.first
          get "/api/orders/#{line_item.order.id}/line_items/#{line_item.id}", :format => :json
        end

        it_should_behave_like "status ok"

        it "should return line item information" do
          page = JSON.load(last_response.body)
          page['line_item']['description'].should match(/Size: S/)
          page['line_item']['price'].should  be_true
          page['line_item']['quantity'].should be_true
        end
      end
    end

    context "with an unauthorized user" do
      before(:each) do
        2.times { Factory(:line_item) }
        line_item = Spree::LineItem.last
        get "/api/orders/#{line_item.order.id}/line_items", :format => :json
      end

      it_should_behave_like "unauthorized"
    end
  end
end
