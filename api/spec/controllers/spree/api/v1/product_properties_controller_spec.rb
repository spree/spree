require 'spec_helper'
require 'shared_examples/protect_product_actions'

module Spree
  describe Spree::Api::V1::ProductPropertiesController do
    render_views

    let!(:product) { create(:product) }
    let!(:property_1) {product.product_properties.create(:property_name => "My Property 1", :value => "my value 1")}
    let!(:property_2) {product.product_properties.create(:property_name => "My Property 2", :value => "my value 2")}
    
    let(:attributes) { [:id, :product_id, :property_id, :value, :property_name] }
    let(:resource_scoping) { { :product_id => product.to_param } }

    before do
      stub_authentication!
    end
    
    it "can see a list of all product properties" do
      api_get :index
      json_response.count.should eq 2
      json_response.first.should have_attributes(attributes)
    end
    
    it "can see a single product_property" do
      api_get :show, :property_name => property_1.property_name
      json_response.count.should eq 1
      json_response.should have_attributes(attributes)
    end
    
    it "can learn how to create a new product property" do
      api_get :new
      json_response["attributes"].should == attributes.map(&:to_s)
      json_response["required_attributes"].should be_empty
    end
    
    it "cannot create a new product property if not an admin" do
      api_post :create, :product_property => { :property_name => "My Property 3" }
      assert_unauthorized!
    end
    
    it "cannot update a product property" do
      api_put :update, :property_name => property_1.property_name, :product_property => { :value => "my value 456" }
      assert_unauthorized!
    end
    
    it "cannot delete a product property" do
      api_delete :destroy, :property_name => property_1.property_name
      assert_unauthorized!
      lambda { property_1.reload }.should_not raise_error
    end
    
    context "as an admin" do
      sign_in_as_admin!

      it "can create a new product property" do
        expect do
          api_post :create, :product_property => { :property_name => "My Property 3", :value => "my value 3" }  
        end.to change(product.product_properties, :count).by(1)
        json_response.should have_attributes(attributes)
        response.status.should == 201
      end

      it "can update a product property" do
        api_put :update, :property_name => property_1.property_name, :product_property => { :value => "my value 456" }
        response.status.should == 200
      end

      it "can delete a variant" do
        api_delete :destroy, :property_name => property_1.property_name
        response.status.should == 200
        lambda { property_1.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end
    
  end
end