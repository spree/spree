require 'shared_examples/protect_product_actions'
require 'spec_helper'

module Spree
  describe Spree::Api::ProductsController do
    render_views

    let!(:product) { create(:product) }
    let(:attributes) { [:id, :name, :description, :price, :available_on, :permalink, :count_on_hand, :meta_description, :meta_keywords, :taxon_ids] }

    context "without authentication" do
      before { Spree::Api::Config[:requires_authentication] = false }

      it "retreives a list of products" do
        api_get :index
        json_response["products"].first.should have_attributes(attributes)
        json_response["count"].should == 1
        json_response["current_page"].should == 1
        json_response["pages"].should == 1
      end

      it_behaves_like "modifying product actions are restricted"
    end
  end
end

