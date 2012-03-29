require 'spec_helper'

describe "Products" do
  context "GET" do
    context "with an authorized api user" do
      context "retreiving all products" do
        before(:each) do
          2.times { Factory(:product) }
          @user = Factory(:admin_user)
          api_login(@user)
          get "/api/products", :format => :json
        end

        it_should_behave_like "status ok"

        it "should return an array with 2 products" do
          page = JSON.load(last_response.body)

          page.map { |d| d['name'] }.length.should == 2.to_i
          page.first.keys.sort.should == ["product"]

          keys = ["available_on", "count_on_hand", "created_at", "deleted_at", "description", "id", "meta_description", "meta_keywords", "name", "permalink", "shipping_category_id", "tax_category_id", "updated_at"]
          page.first['product'].keys.sort.should == keys
        end
      end

      context "retrieving a specific product" do
        before(:each) do
          2.times { Factory(:product) }
          @user = Factory(:admin_user)
          api_login(@user)
          get "/api/products/#{Spree::Product.first.id}", :format => :json
        end

        it_should_behave_like "status ok"

        it "should return product information" do
          page = JSON.load(last_response.body)
          page['product']['permalink'].should  be_true
          page['product']['name'].should  be_true
          page['product']['count_on_hand'].should  be_true
        end
      end

      context "searching products" do
        before(:each) do
          Factory(:product, :name => "apache baseball cap")
          Factory(:product, :name => "zomg shirt")
          @user = Factory(:admin_user)
          api_login(@user)
          get "/api/products.json?search[name_cont]=shirt", :format => :json
        end

        it_should_behave_like "status ok"

        it "should return an array with 1 product" do
          page = JSON.load(last_response.body)

          page.map { |d| d['name'] }.length.should == 1.to_i
          page.first.keys.sort.should == ["product"]

          keys = ["available_on", "count_on_hand", "created_at", "deleted_at", "description", "id", "meta_description", "meta_keywords", "name", "permalink", "shipping_category_id", "tax_category_id", "updated_at"]
          page.first['product'].keys.sort.should == keys
        end

        it "should return product information for shirt" do
          page = JSON.load(last_response.body).first
          page['product']['permalink'].should  be_true
          page['product']['name'].should  == 'zomg shirt'
          page['product']['count_on_hand'].should  be_true
        end
      end
    end

    context "with an unauthorized user" do
      before(:each) do
        2.times { Factory(:product) }
        get "/api/products", :format => :json
      end

      it_should_behave_like "unauthorized"
    end
  end
end
