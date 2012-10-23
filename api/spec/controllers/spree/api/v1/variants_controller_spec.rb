require 'spec_helper'

module Spree
  describe Api::V1::VariantsController do
    render_views


    let!(:product) { create(:product) }
    let!(:variant) do
      variant = product.master
      variant.option_values << create(:option_value)
      variant
    end
    let!(:attributes) { [:id, :name, :count_on_hand,
                         :sku, :price, :weight, :height,
                         :width, :depth, :is_master, :cost_price,
                         :permalink] }

    before do
      stub_authentication!
    end

    it "can see a paginated list of variants" do
      api_get :index
      json_response["variants"].first.should have_attributes(attributes)
      json_response["count"].should == 1
      json_response["current_page"].should == 1
      json_response["pages"].should == 1
    end

    it "variants returned contain option values data" do
      api_get :index
      option_values = json_response["variants"].last["variant"]["option_values"]
      option_values.first.should have_attributes([:name,
                                                 :presentation,
                                                 :option_type_name,
                                                 :option_type_id])
    end

    context "pagination" do
      default_per_page(1)

      it "can select the next page of variants" do
        second_variant = create(:variant)
        api_get :index, :page => 2
        json_response["variants"].first.should have_attributes(attributes)
        json_response["count"].should == 3
        json_response["current_page"].should == 2
        json_response["pages"].should == 3
      end
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

    it "can learn how to create a new variant" do
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

        variant.product.variants.count.should == 1
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
