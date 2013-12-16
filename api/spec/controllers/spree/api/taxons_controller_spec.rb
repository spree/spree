require 'spec_helper'

module Spree
  describe Api::TaxonsController do
    render_views

    let(:taxonomy) { create(:taxonomy) }
    let(:taxon) { create(:taxon, :name => "Ruby", :taxonomy => taxonomy) }
    let(:taxon2) { create(:taxon, :name => "Rails", :taxonomy => taxonomy) }
    let(:attributes) { ["id", "name", "pretty_name", "permalink", "parent_id", "taxonomy_id"] }

    before do
      stub_authentication!
      taxon2.children << create(:taxon, :name => "3.2.2", :taxonomy => taxonomy)
      taxon.children << taxon2
      taxonomy.root.children << taxon
    end

    context "as a normal user" do
      it "gets all taxons for a taxonomy" do
        api_get :index, :taxonomy_id => taxonomy.id

        json_response['taxons'].first['name'].should eq taxon.name
        children = json_response['taxons'].first['taxons']
        children.count.should eq 1
        children.first['name'].should eq taxon2.name
        children.first['taxons'].count.should eq 1
      end

      # Regression test for #4112
      it "does not include children when asked not to" do
        api_get :index, :taxonomy_id => taxonomy.id, :without_children => 1

        json_response['taxons'].first['name'].should eq(taxon.name)
        json_response['taxons'].first['taxons'].should be_nil
      end

      it "paginates through taxons" do
        new_taxon = create(:taxon, :name => "Go", :taxonomy => taxonomy)
        taxonomy.root.children << new_taxon
        expect(taxonomy.root.children.count).to eql(2)
        api_get :index, :taxonomy_id => taxonomy.id, :page => 1, :per_page => 1
        expect(json_response["count"]).to eql(1)
        expect(json_response["total_count"]).to eql(2)
        expect(json_response["current_page"]).to eql(1)
        expect(json_response["per_page"]).to eql(1)
        expect(json_response["pages"]).to eql(2)
      end

      it "gets all taxons" do
        api_get :index

        json_response['taxons'].first['name'].should eq taxonomy.root.name
        children = json_response['taxons'].first['taxons']
        children.count.should eq 1
        children.first['name'].should eq taxon.name
        children.first['taxons'].count.should eq 1
      end

      it "can search for a single taxon" do
        api_get :index, :q => { :name_cont => "Ruby" }

        json_response['taxons'].count.should == 1
        json_response['taxons'].first['name'].should eq "Ruby"
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
        api_post :create, :taxonomy_id => taxonomy.id, :taxon => { :name => "Colors" }
        json_response.should have_attributes(attributes)
        response.status.should == 201

        taxonomy.reload.root.children.count.should eq 2
        taxon = Spree::Taxon.where(:name => 'Colors').first

        taxon.parent_id.should eq taxonomy.root.id
        taxon.taxonomy_id.should eq taxonomy.id
      end

      it "can update the position in the list" do
        taxonomy.root.children << taxon2
        api_put :update, :taxonomy_id => taxonomy.id, :id => taxon.id, :taxon => {:parent_id => taxon.parent_id, :child_index => 2 }
        response.status.should == 200
        taxonomy.reload.root.children[0].should eql taxon2
        taxonomy.reload.root.children[1].should eql taxon
      end

      it "cannot create a new taxon with invalid attributes" do
        api_post :create, :taxonomy_id => taxonomy.id, :taxon => {}
        response.status.should == 422
        json_response["error"].should == "Invalid resource. Please fix errors and try again."
        errors = json_response["errors"]

        taxonomy.reload.root.children.count.should eq 1
      end

      it "cannot create a new taxon with invalid taxonomy_id" do
        api_post :create, :taxonomy_id => 1000, :taxon => { :name => "Colors" }
        response.status.should == 422
        json_response["error"].should == "Invalid resource. Please fix errors and try again."

        errors = json_response["errors"]
        errors["taxonomy_id"].should_not be_nil
        errors["taxonomy_id"].first.should eq "Invalid taxonomy id."

        taxonomy.reload.root.children.count.should eq 1
      end

      it "can destroy" do
        api_delete :destroy, :taxonomy_id => taxonomy.id, :id => taxon.id
        response.status.should == 204
      end
    end

  end
end
