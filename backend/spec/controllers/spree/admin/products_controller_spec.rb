require 'spec_helper'

describe Spree::Admin::ProductsController, type: :controller do
  stub_authorization!

  context "#index" do
    let(:ability_user) { stub_model(Spree::LegacyUser, has_spree_role?: true) }

    # Regression test for #1259
    it "can find a product by SKU" do
      product = create(:product, sku: "ABC123")
      spree_get :index, q: { sku_start: "ABC123" }
      expect(assigns[:collection]).not_to be_empty
      expect(assigns[:collection]).to include(product)
    end
  end

  # regression test for #1370
  context "adding properties to a product" do
    let!(:product) { create(:product) }
    specify do
      spree_put :update, id: product.to_param, product: { product_properties_attributes: { "1" => { property_name: "Foo", value: "bar" } } }
      expect(flash[:success]).to eq("Product #{product.name.inspect} has been successfully updated!")
    end

  end

  # regression test for #801
  describe '#destroy' do
    let(:product) { mock_model(Spree::Product) }
    let(:products) { double(ActiveRecord::Relation) }

    def send_request
      spree_delete :destroy, id: product, format: :js
    end

    context 'will successfully destroy product' do
      before do
        allow(Spree::Product).to receive(:friendly).and_return(products)
        allow(products).to receive(:find).with(product.id.to_s).and_return(product)
        allow(product).to receive(:destroy).and_return(true)
      end

      describe 'expects to receive' do
        it { expect(Spree::Product).to receive(:friendly).and_return(products) }
        it { expect(products).to receive(:find).with(product.id.to_s).and_return(product) }
        it { expect(product).to receive(:destroy).and_return(true) }

        after { send_request }
      end

      describe 'assigns' do
        before { send_request }
        it { expect(assigns(:product)).to eq(product) }
      end

      describe 'response' do
        before { send_request }
        it { expect(response).to have_http_status(:ok) }
        it { expect(flash[:success]).to eq(Spree.t('notice_messages.product_deleted')) }
      end
    end

    context 'will not successfully destroy product' do
      before do
        allow(Spree::Product).to receive(:friendly).and_return(products)
        allow(products).to receive(:find).with(product.id.to_s).and_return(product)
        allow(product).to receive(:destroy).and_return(false)
      end

      describe 'expects to receive' do
        it { expect(Spree::Product).to receive(:friendly).and_return(products) }
        it { expect(products).to receive(:find).with(product.id.to_s).and_return(product) }
        it { expect(product).to receive(:destroy).and_return(false) }

        after { send_request }
      end

      describe 'assigns' do
        before { send_request }
        it { expect(assigns(:product)).to eq(product) }
      end

      describe 'response' do
        before { send_request }
        it { expect(response).to have_http_status(:ok) }
        it { expect(flash[:error]).to eq(Spree.t('notice_messages.product_not_deleted')) }
      end
    end
  end

  context "stock" do
    let(:product) { create(:product) }
    it "restricts stock location based on accessible attributes" do
      expect(Spree::StockLocation).to receive(:accessible_by).and_return([])
      spree_get :stock, id: product
    end
  end
end
