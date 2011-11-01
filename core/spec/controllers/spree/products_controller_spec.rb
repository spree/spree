require 'spec_helper'

module Spree
  describe ProductsController do

    describe "#show" do
      before do
        Product.stub(:find_by_permalink!).and_return(Factory(:product))
      end

      context "when the :taxon param is present" do
        let(:taxon_id) { '123' }

        it "retrieves the Taxon by ID" do
          Taxon.should_receive(:find).with(taxon_id)
          get :show, :taxon => taxon_id
        end
      end

      context "when the :taxon param is not present" do
        it "doesn't retrieve the Taxon by ID" do
          Taxon.should_not_receive(:find)
          get :show
        end
      end
    end
  end
end
