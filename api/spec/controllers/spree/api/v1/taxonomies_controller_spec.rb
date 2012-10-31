require 'spec_helper'

module Spree
  describe Api::V1::TaxonomiesController do
    render_views

    let(:taxonomy) { create(:taxonomy) }
    let(:taxon) { create(:taxon, :name => "Ruby", :taxonomy => taxonomy) }
    let(:taxon2) { create(:taxon, :name => "Rails", :taxonomy => taxonomy) }
    let(:attributes) { [:id, :name] }

    before do
      stub_authentication!
      taxon2.children << create(:taxon, :name => "3.2.2", :taxonomy => taxonomy)
      taxon.children << taxon2
      taxonomy.root.children << taxon
    end

    context "as a normal user" do
      it "gets all taxonomies" do
        api_get :index

        json_response["taxonomies"].first['taxonomy']['name'].should eq taxonomy.name
        json_response["taxonomies"].first['taxonomy']['root']['taxons'].count.should eq 1
      end

      it 'can control the page size through a parameter' do
        create(:taxonomy)
        api_get :index, :per_page => 1
        json_response['count'].should == 1
        json_response['current_page'].should == 1
        json_response['pages'].should == 2
      end

      it 'can query the results through a paramter' do
        expected_result = create(:taxonomy, :name => 'Style')
        api_get :index, :q => { :name_cont => 'style' }
        json_response['count'].should == 1
        json_response['taxonomies'].first['taxonomy']['name'].should eq expected_result.name
      end

      it "gets a single taxonomy" do
        api_get :show, :id => taxonomy.id

        json_response['taxonomy']['name'].should eq taxonomy.name

        children = json_response['taxonomy']['root']['taxons']
        children.count.should eq 1
        children.first['taxon']['name'].should eq taxon.name
        children.first['taxon'].key?('taxons').should be_false
      end

      it "gets a single taxonomy with set=nested" do
        api_get :show, :id => taxonomy.id, :set => 'nested'

        json_response['taxonomy']['name'].should eq taxonomy.name

        children = json_response['taxonomy']['root']['taxons']
        children.first['taxon'].key?('taxons').should be_true
      end

      it "gets the jstree-friendly version of a taxonomy" do
        api_get :jstree, :id => taxonomy.id
        json_response["data"].should eq(taxonomy.root.name)
        json_response["attr"].should eq({ "id" => taxonomy.root.id, "name" => taxonomy.root.name})
        json_response["state"].should eq("open")
      end

      it "can learn how to create a new taxonomy" do
        api_get :new
        json_response["attributes"].should == attributes.map(&:to_s)
        required_attributes = json_response["required_attributes"]
        required_attributes.should include("name")
      end

      it "cannot create a new taxonomy if not an admin" do
        api_post :create, :taxonomy => { :name => "Location" }
        assert_unauthorized!
      end

      it "cannot update a taxonomy" do
        api_put :update, :id => taxonomy.id, :taxonomy => { :name => "I hacked your store!" }
        assert_unauthorized!
      end

      it "cannot delete a taxonomy" do
        api_delete :destroy, :id => taxonomy.id
        assert_unauthorized!
      end
    end

    context "as an admin" do
      sign_in_as_admin!

      it "can create" do
        api_post :create, :taxonomy => { :name => "Colors"}
        json_response.should have_attributes(attributes)
        response.status.should == 201
      end

      it "cannot create a new taxonomy with invalid attributes" do
        api_post :create, :taxonomy => {}
        response.status.should == 422
        json_response["error"].should == "Invalid resource. Please fix errors and try again."
        errors = json_response["errors"]
      end

      it "can destroy" do
        api_delete :destroy, :id => taxonomy.id
        response.status.should == 204
      end
    end
  end
end
