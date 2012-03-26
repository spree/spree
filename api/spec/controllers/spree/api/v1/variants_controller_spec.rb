require 'spec_helper'

module Spree
  describe Api::V1::VariantsController do
    let!(:variant) { Factory(:variant, :option_values => [Factory(:option_value)]) }
    let!(:attributes) { [:id, :name, :count_on_hand,
                         :sku, :price, :weight, :height,
                         :width, :depth, :is_master, :cost_price] }

    before do
      stub_authentication!
    end

    it "can see a list of all variants" do
      api_get :index
      json_response.first.should have_attributes(attributes)
      p json_response.first["variant"]
      option_values = json_response.first["variant"]["option_values"]
      option_values.first.should have_attributes([:name,
                                                 :presentation,
                                                 :option_type_name,
                                                 :option_type_id])
    end

    it "can see a single variant" do
      api_get :show, :id => variant.to_param
      json_response.should have_attributes(attributes)
      option_values = json_response["variant"]["option_values"]
      option_values.first.should have_attributes([:name,
                                                 :presentation,
                                                 :option_type_name,
                                                 :option_type_id])
    end

    it "can learn how to create a new product" do
      api_get :new
      json_response["attributes"].should == attributes.map(&:to_s)
      json_response["required_attributes"].should be_empty
    end

    it "cannot create a new variant if not an admin" do
      api_post :create, :variant => { :sku => "12345" }
      assert_unauthorized!
    end

    it "cannot update a variant" do
      api_put :update, :id => variant.to_param, :variant => { :sku => "12345" }
      assert_unauthorized!
    end

    it "cannot delete a variant" do
      api_delete :destroy, :id => variant.to_param
      assert_unauthorized!
      lambda { variant.reload }.should_not raise_error
    end

    context "as an admin" do
      sign_in_as_admin!
      let(:resource_scoping) { { :product_id => variant.product.to_param } }

      it "can create a new variant" do
        api_post :create, :variant => { :sku => "12345" }
        json_response.should have_attributes(attributes)
        response.status.should == 201

        variant.product.variants.count.should == 2
      end

      it "can update a variant" do
        api_put :update, :id => variant.to_param, :variant => { :sku => "12345" }
        response.status.should == 200
      end

      it "can delete a variant" do
        api_delete :destroy, :id => variant.to_param
        response.status.should == 200
        lambda { variant.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end


  end
end
