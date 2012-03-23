require 'spec_helper'

module Spree
  describe Spree::Api::V1::ProductsController do
    let!(:product) { Factory(:product) }
    let(:attributes) { [:id, :name, :description, :price, :available_on, :permalink] }

    before do
      stub_authentication!
    end

    context "as a normal user" do
      it "retrieves a list of products" do
        api_get :index
        json_response.first.should have_attributes(attributes)
      end

      it "can select the next page of products" do
        Product.should_receive(:page).with("1").and_return([])
        api_get :index, :page => 1
      end

      it "gets a single product" do
        api_get :show, :id => product.to_param
        json_response.should have_attributes(attributes)
      end

      it "can learn how to create a new product" do
        api_get :new
        json_response["attributes"].should == attributes.map(&:to_s)
        required_attributes = json_response["required_attributes"]
        required_attributes.should include("name")
        required_attributes.should include("price")
      end

      it "cannot create a new product if not an admin" do
        api_post :create, :product => { :name => "Brand new product!" }
        assert_unauthorized!
      end

      it "cannot update a product" do
        api_put :update, :id => product.to_param, :product => { :name => "I hacked your store!" }
        assert_unauthorized!
      end

      it "cannot delete a product" do
        api_delete :destroy, :id => product.to_param
        assert_unauthorized!
      end
    end

    context "as an admin" do
      let!(:current_user) do
        user = stub_model(User)
        user.should_receive(:has_role?).with("admin").and_return(true)
        user
      end

      it "can create a new product" do
        api_post :create, :product => { :name => "The Other Product",
                                        :price => 19.99 }
        json_response.should have_attributes(attributes)
        response.status.should == 201
      end

      it "cannot create a new product with invalid attributes" do
        api_post :create, :product => {}
        response.status.should == 422
        json_response["error"].should == "Invalid resource. Please fix errors and try again."
        json_response["errors"].keys.should == ["name", "price"]
      end

      it "can update a product" do
        api_put :update, :id => product.to_param, :product => { :name => "New and Improved Product!" }
        response.status.should == 200
      end

      it "cannot update a product with an invalid attribute" do
        api_put :update, :id => product.to_param, :product => { :name => "" }
        response.status.should == 422
        json_response["error"].should == "Invalid resource. Please fix errors and try again."
        json_response["errors"]["name"].should == ["can't be blank"]
      end

      it "can delete a product" do
        api_delete :destroy, :id => product.to_param
        response.status.should == 200
      end
    end
  end
end
