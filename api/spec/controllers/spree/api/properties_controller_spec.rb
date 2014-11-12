require 'spec_helper'
module Spree
  describe Spree::Api::PropertiesController, :type => :controller do
    render_views

    let!(:property_1) { Property.create!(:name => "foo", :presentation => "Foo") }
    let!(:property_2) { Property.create!(:name => "bar", :presentation => "Bar") }

    let(:attributes) { [:id, :name, :presentation] }

    before do
      stub_authentication!
    end

    it "can see a list of all properties" do
      api_get :index
      expect(json_response["properties"].count).to eq(2)
      expect(json_response["properties"].first).to have_attributes(attributes)
    end

    it "can control the page size through a parameter" do
      api_get :index, :per_page => 1
      expect(json_response['properties'].count).to eq(1)
      expect(json_response['current_page']).to eq(1)
      expect(json_response['pages']).to eq(2)
    end

    it 'can query the results through a parameter' do
      api_get :index, :q => { :name_cont => 'ba' }
      expect(json_response['count']).to eq(1)
      expect(json_response['properties'].first['presentation']).to eq property_2.presentation
    end

    it "retrieves a list of properties by id" do
      api_get :index, :ids => [property_1.id]
      expect(json_response["properties"].first).to have_attributes(attributes)
      expect(json_response["count"]).to eq(1)
    end

    it "retrieves a list of properties by ids string" do
      api_get :index, :ids => [property_1.id, property_2.id].join(",")
      expect(json_response["properties"].first).to have_attributes(attributes)
      expect(json_response["properties"][1]).to have_attributes(attributes)
      expect(json_response["count"]).to eq(2)
    end

    it "can see a single property" do
      api_get :show, :id => property_1.id
      expect(json_response).to have_attributes(attributes)
    end

    it "can see a property by name" do
      api_get :show, :id => property_1.name
      expect(json_response).to have_attributes(attributes)
    end

    it "can learn how to create a new property" do
      api_get :new
      expect(json_response["attributes"]).to eq(attributes.map(&:to_s))
      expect(json_response["required_attributes"]).to be_empty
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
      expect { property_1.reload }.not_to raise_error
    end

    context "as an admin" do
      sign_in_as_admin!

      it "can create a new property" do
        expect(Spree::Property.count).to eq(2)
        api_post :create, :property => { :name => "My Property 3", :presentation => "my value 3" }
        expect(json_response).to have_attributes(attributes)
        expect(response.status).to eq(201)
        expect(Spree::Property.count).to eq(3)
      end

      it "can update a property" do
        api_put :update, :id => property_1.name, :property => { :presentation => "my value 456" }
        expect(response.status).to eq(200)
      end

      it "can delete a property" do
        api_delete :destroy, :id => property_1.name
        expect(response.status).to eq(204)
        expect { property_1.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
