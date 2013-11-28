require 'spec_helper'

module Spree
  describe Api::ClassificationsController do
    let(:taxon) do
      taxon = create(:taxon)
      3.times do
        product = create(:product)
        product.taxons << taxon
      end
      taxon
    end

    before do
      stub_authentication!
    end

    context "as a user" do
      it "cannot change the order of a product" do
        api_put :update, :taxon_id => taxon, :product_id => taxon.products.first, :position => 1
        response.status.should == 401
      end
    end

    context "as an admin" do
      sign_in_as_admin!

      it "can change the order a product" do
        last_product = taxon.products.last
        classification = taxon.classifications.find_by(:product_id => last_product.id)
        classification.position.should == 3
        api_put :update, :taxon_id => taxon, :product_id => last_product, :position => 0
        response.status.should == 200
        classification.reload.position.should == 1
      end
    end
  end
end