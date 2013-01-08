require 'spec_helper'

module Spree
  describe Api::TaxonsController do
    render_views

    let(:taxonomy) { create(:taxonomy) }
    let(:taxon) { create(:taxon, :name => "Ruby", :taxonomy => taxonomy) }
    let(:taxon2) { create(:taxon, :name => "Rails", :taxonomy => taxonomy) }
    let(:attributes) { ["id", "name", "pretty_name", "permalink", "position", "parent_id", "taxonomy_id"] }

    before do
      stub_authentication!
      taxon2.children << create(:taxon, :name => "3.2.2", :taxonomy => taxonomy)
      taxon.children << taxon2
      taxonomy.root.children << taxon
    end

    context "as a normal user" do
      it "gets all taxons for a taxonomy" do
        api_get :index, :taxonomy_id => taxonomy.id

        json_response.first['name'].should eq taxon.name
        children = json_response.first['taxons']
        children.count.should eq 1
        children.first['name'].should eq taxon2.name
        children.first['taxons'].count.should eq 1
      end

      it "gets all taxons" do
        api_get :index

        json_response.first['name'].should eq taxonomy.root.name
        children = json_response.first['taxons']
        children.count.should eq 1
        children.first['name'].should eq taxon.name
        children.first['taxons'].count.should eq 1
      end

      it "can search for a single taxon" do
        api_get :index, :q => { :name_cont => "Ruby" }

        json_response.count.should == 1
        json_response.first['name'].should eq "Ruby"
      end

      it "gets a single taxon" do
        api_get :show, :id => taxon.id, :taxonomy_id => taxonomy.id

        json_response['name'].should eq taxon.name
        json_response['taxons'].count.should eq 1
      end

      it "gets all taxons in JSTree form" do
        api_get :jstree, :taxonomy_id => taxonomy.id, :id => taxon.id
        response = json_response.first
        response["data"].should eq(taxon2.name)
        response["attr"].should eq({ "name" => taxon2.name, "id" => taxon2.id})
        response["state"].should eq("closed")
      end



      it "can learn how to create a new taxon" do
        api_get :new, :taxonomy_id => taxonomy.id
        json_response["attributes"].should == attributes.map(&:to_s)
        required_attributes = json_response["required_attributes"]
        required_attributes.should include("name")
      end

      it "cannot create a new taxon if not an admin" do
        api_post :create, :taxonomy_id => taxonomy.id, :taxon => { :name => "Location" }
        assert_unauthorized!
      end

      it "cannot update a taxon" do
        api_put :update, :taxonomy_id => taxonomy.id, :id => taxon.id, :taxon => { :name => "I hacked your store!" }
        assert_unauthorized!
      end

      it "cannot delete a taxon" do
        api_delete :destroy, :taxonomy_id => taxonomy.id, :id => taxon.id
        assert_unauthorized!
      end
    end

    context "as an admin" do
      sign_in_as_admin!

      it "can create" do
        api_post :create, :taxonomy_id => taxonomy.id, :taxon => { :name => "Colors", :parent_id => taxon.id}
        json_response.should have_attributes(attributes)
        response.status.should == 201

        taxon.reload.children.count.should eq 2
      end

      it "cannot create a new taxon with invalid attributes" do
        api_post :create, :taxonomy_id => taxonomy.id, :taxon => {}
        response.status.should == 422
        json_response["error"].should == "Invalid resource. Please fix errors and try again."
        errors = json_response["errors"]

        taxon.reload.children.count.should eq 1
      end

      it "can destroy" do
        api_delete :destroy, :taxonomy_id => taxonomy.id, :id => taxon.id
        response.status.should == 204
      end
    end

  end
end
