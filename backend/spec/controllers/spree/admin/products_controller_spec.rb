require 'spec_helper'

describe Spree::Admin::ProductsController, :type => :controller do
  stub_authorization!

  context "#index" do
    let(:ability_user) { stub_model(Spree::LegacyUser, :has_spree_role? => true) }

    # Regression test for #1259
    it "can find a product by SKU" do
      product = create(:product, :sku => "ABC123")
      spree_get :index, :q => { :sku_start => "ABC123" }
      expect(assigns[:collection]).not_to be_empty
      expect(assigns[:collection]).to include(product)
    end
  end

  # regression test for #1370
  context "adding properties to a product" do
    let!(:product) { create(:product) }
    specify do
      spree_put :update, :id => product.to_param, :product => { :product_properties_attributes => { "1" => { :property_name => "Foo", :value => "bar" } } }
      expect(flash[:success]).to eq("Product #{product.name.inspect} has been successfully updated!")
    end

  end


  # regression test for #801
  context "destroying a product" do
    let(:product) do
      product = create(:product)
      create(:variant, :product => product)
      product
    end

    it "deletes all the variants (including master) for the product" do
      spree_delete :destroy, :id => product
      expect(product.reload.deleted_at).not_to be_nil
      product.variants_including_master.each do |variant|
        expect(variant.reload.deleted_at).not_to be_nil
      end
    end
  end

  context "stock" do
    let(:product) { create(:product) }
    it "restricts stock location based on accessible attributes" do
      expect(Spree::StockLocation).to receive(:accessible_by).and_return([])
      spree_get :stock, :id => product
    end
  end
end
