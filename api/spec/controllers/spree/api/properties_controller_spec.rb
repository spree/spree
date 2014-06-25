require 'spec_helper'
module Spree
  describe Spree::Api::PropertiesController do
    render_views

    let!(:property_1) { Property.create!(:name => "foo", :presentation => "Foo") }
    let!(:property_2) { Property.create!(:name => "bar", :presentation => "Bar") }

    let(:attributes) { [:id, :name, :presentation] }

    before do
      stub_authentication!
    end

    it "can see a list of all properties" do
      api_get :index
      json_response["properties"].count.should eq(2)
      json_response["properties"].first.should have_attributes(attributes)
    end

    it "can control the page size through a parameter" do
      api_get :index, :per_page => 1
      json_response['properties'].count.should == 1
      json_response['current_page'].should == 1
      json_response['pages'].should == 2
    end

    it 'can query the results through a parameter' do
      api_get :index, :q => { :name_cont => 'ba' }
      json_response['count'].should == 1
      json_response['properties'].first['presentation'].should eq property_2.presentation
    end

    it "retrieves a list of properties by id" do
      api_get :index, :ids => [property_1.id]
      json_response["properties"].first.should have_attributes(attributes)
      json_response["count"].should == 1
    end

    it "retrieves a list of properties by ids string" do
      api_get :index, :ids => [property_1.id, property_2.id].join(",")
      json_response["properties"].first.should have_attributes(attributes)
      json_response["properties"][1].should have_attributes(attributes)
      json_response["count"].should == 2
    end

    it "can see a single property" do
      api_get :show, :id => property_1.id
      json_response.should have_attributes(attributes)
    end

    it "can see a property by name" do
      api_get :show, :id => property_1.name
      json_response.should have_attributes(attributes)
    end

    it "can learn how to create a new property" do
      api_get :new
      json_response["attributes"].should == attributes.map(&:to_s)
      json_response["required_attributes"].should be_empty
    end

    it "cannot create a new property if not an admin" do
      api_post :create, :property => { :name => "My Property 3" }
      assert_unauthorized!
    end

    it "cannot update a property" do
      api_put :update, :id => property_1.name, :property => { :presentation => "my value 456" }
      assert_unauthorized!
    end

    it "cannot delete a property" do
      api_delete :destroy, :id => property_1.id
      assert_unauthorized!
      lambda { property_1.reload }.should_not raise_error
    end

    context "as an admin" do
      sign_in_as_admin!

      it "can create a new property" do
        Spree::Property.count.should == 2
        api_post :create, :property => { :name => "My Property 3", :presentation => "my value 3" }
        json_response.should have_attributes(attributes)
        response.status.should == 201
        Spree::Property.count.should == 3
      end

      it "can update a property" do
        api_put :update, :id => property_1.name, :property => { :presentation => "my value 456" }
        response.status.should == 200
      end

      it "can delete a property" do
        api_delete :destroy, :id => property_1.name
        response.status.should == 204
        lambda { property_1.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
