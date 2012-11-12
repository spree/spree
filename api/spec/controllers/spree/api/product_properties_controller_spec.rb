require 'spec_helper'
require 'shared_examples/protect_product_actions'

module Spree
  describe Spree::Api::ProductPropertiesController do
    render_views

    let!(:product) { create(:product) }
    let!(:property_1) {product.product_properties.create(:property_name => "My Property 1", :value => "my value 1")}
    let!(:property_2) {product.product_properties.create(:property_name => "My Property 2", :value => "my value 2")}

    let(:attributes) { [:id, :product_id, :property_id, :value, :property_name] }
    let(:resource_scoping) { { :product_id => product.to_param } }

    before do
      stub_authentication!
    end

    context "if product is deleted" do
      before do
        product.update_column(:deleted_at, Time.now)
      end

      it "can not see a list of product properties" do
        api_get :index
        response.status.should == 404
      end
    end

    it "can see a list of all product properties" do
      api_get :index
      json_response["product_properties"].count.should eq 2
      json_response["product_properties"].first.should have_attributes(attributes)
    end

    it "can control the page size through a parameter" do
      api_get :index, :per_page => 1
      json_response['product_properties'].count.should == 1
      json_response['current_page'].should == 1
      json_response['pages'].should == 2
    end

    it 'can query the results through a paramter' do
      Spree::ProductProperty.last.update_attribute(:value, 'loose')
      property = Spree::ProductProperty.last
      api_get :index, :q => { :value_cont => 'loose' }
      json_response['count'].should == 1
      json_response['product_properties'].first['product_property']['value'].should eq property.value
    end

    it "can see a single product_property" do
      api_get :show, :id => property_1.property_name
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
      api_put :update, :id => property_1.property_name, :product_property => { :value => "my value 456" }
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
        api_put :update, :id => property_1.property_name, :product_property => { :value => "my value 456" }
        response.status.should == 200
      end

      it "can delete a variant" do
        api_delete :destroy, :id => property_1.property_name
        response.status.should == 204
        lambda { property_1.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "with product identified by id" do
      let(:resource_scoping) { { :product_id => product.id } }
      it "can see a list of all product properties" do
        api_get :index
        json_response["product_properties"].count.should eq 2
        json_response["product_properties"].first.should have_attributes(attributes)
      end

      it "can see a single product_property by id" do
        api_get :show, :id => property_1.id
        json_response.count.should eq 1
        json_response.should have_attributes(attributes)
      end
    end

  end
end
