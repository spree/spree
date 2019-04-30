require 'spec_helper'

describe Spree::Admin::ProductsController, type: :controller do
  stub_authorization!

  context '#index' do
    let(:ability_user) { stub_model(Spree::LegacyUser, has_spree_role?: true) }

    # Regression test for #1259
    it 'can find a product by SKU' do
      product = create(:product, sku: 'ABC123')
      get :index, params: { q: { sku_start: 'ABC123' } }
      expect(assigns[:collection]).not_to be_empty
      expect(assigns[:collection]).to include(product)
    end
  end

  # regression test for #1370
  context 'adding properties to a product' do
    let!(:product) { create(:product) }

    specify do
      put :update, params: {
        id: product.to_param,
        product: { product_properties_attributes: { '1' => { property_name: 'Foo', value: 'bar' } } }
      }
      expect(flash[:success]).to eq("Product #{product.name.inspect} has been successfully updated!")
    end
  end

  # regression test for #801
  describe '#destroy' do
    let(:product) { mock_model(Spree::Product) }
    let(:products) { double(ActiveRecord::Relation) }

    def send_request
      delete :destroy, params: { id: product, format: :js }
    end

    context 'will successfully destroy product' do
      before do
        allow(Spree::Product).to receive(:friendly).and_return(products)
        allow(products).to receive(:find).with(product.id.to_s).and_return(product)
        allow(product).to receive(:destroy).and_return(true)
      end

      describe 'expects to receive' do
        after { send_request }

        it { expect(Spree::Product).to receive(:friendly).and_return(products) }
        it { expect(products).to receive(:find).with(product.id.to_s).and_return(product) }
        it { expect(product).to receive(:destroy).and_return(true) }
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
      let(:error_msg) { 'Failed to delete' }

      before do
        allow(Spree::Product).to receive(:friendly).and_return(products)
        allow(products).to receive(:find).with(product.id.to_s).and_return(product)
        allow(product).to receive_message_chain(:errors, :full_messages).and_return([error_msg])
        allow(product).to receive(:destroy).and_return(false)
      end

      describe 'expects to receive' do
        after { send_request }

        it { expect(Spree::Product).to receive(:friendly).and_return(products) }
        it { expect(products).to receive(:find).with(product.id.to_s).and_return(product) }
        it { expect(product).to receive(:destroy).and_return(false) }
      end

      describe 'assigns' do
        before { send_request }

        it { expect(assigns(:product)).to eq(product) }
      end

      describe 'response' do
        before { send_request }

        it { expect(response).to have_http_status(:ok) }

        it 'set flash error' do
          expected_error = Spree.t('notice_messages.product_not_deleted', error: error_msg)
          expect(flash[:error]).to eq(expected_error)
        end
      end
    end
  end

  describe '#clone' do
    subject(:send_request) do
      post :clone, params: { id: product, format: :js }
    end

    let!(:product) { create(:custom_product, name: 'MyProduct', sku: 'MySku') }
    let(:product2) { create(:custom_product, name: 'COPY OF MyProduct', sku: 'COPY OF MySku') }
    let(:variant) { create(:master_variant, name: 'COPY OF MyProduct', sku: 'COPY OF MySku', created_at: product.created_at - 1.day) }

    context 'will successfully clone product' do
      before do
        Timecop.freeze(Date.today + 30)
        allow(product).to receive(:duplicate).and_return(product2)
        send_request
      end

      after do
        Timecop.return
      end

      describe 'response' do
        it { expect(response).to have_http_status(:found) }
        it { expect(response).to be_redirect }
        it { expect(flash[:success]).to eq(Spree.t('notice_messages.product_cloned')) }
      end
    end

    context 'will not successfully clone product' do
      before do
        variant
      end

      describe 'response' do
        before { send_request }

        it { expect(response).to have_http_status(:found) }
        it { expect(response).to be_redirect }

        it 'set flash error' do
          expected_error = Spree.t('notice_messages.product_not_cloned', error: 'Validation failed: Sku has already been taken')
          expect(flash[:error]).to eq(expected_error)
        end
      end
    end
  end

  context 'stock' do
    let(:product) { create(:product) }

    it 'restricts stock location based on accessible attributes' do
      expect(Spree::StockLocation).to receive(:accessible_by).and_return([])
      get :stock, params: { id: product }
    end
  end
end
