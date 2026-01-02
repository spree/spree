require 'spec_helper'

RSpec.describe Spree::Admin::PriceListProductsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:price_list) { create(:price_list, store: store) }

  describe 'GET #index' do
    subject(:index) { get :index, params: { price_list_id: price_list.id } }

    let(:product1) { create(:product, stores: [store]) }
    let(:product2) { create(:product, stores: [store]) }
    let!(:price1) { create(:price, variant: product1.master, price_list: price_list, currency: 'USD', amount: 10.0) }
    let!(:price2) { create(:price, variant: product2.master, price_list: price_list, currency: 'USD', amount: 20.0) }

    it 'renders the products list' do
      index

      expect(response).to render_template(:index)
    end

    it 'assigns the collection' do
      index

      expect(assigns[:collection]).to contain_exactly(product1, product2)
    end
  end

  describe 'GET #bulk_new' do
    subject(:bulk_new_action) { get :bulk_new, params: { price_list_id: price_list.id } }

    it 'renders the new products drawer' do
      bulk_new_action

      expect(response).to render_template(:bulk_new)
    end

    it 'assigns the currency' do
      bulk_new_action

      expect(assigns[:currency]).to eq(store.default_currency)
    end
  end

  describe 'POST #bulk_create' do
    subject(:bulk_create) { post :bulk_create, params: params }

    let(:product1) { create(:product, stores: [store]) }
    let(:product2) { create(:product, stores: [store]) }
    let(:currency) { 'USD' }

    let(:params) do
      {
        price_list_id: price_list.id,
        product_ids: [product1.id, product2.id],
        currency: currency
      }
    end

    it 'creates price records for all variants of the products' do
      expect { bulk_create }.to change(Spree::Price.for_price_list(price_list), :count).by(2)
    end

    it 'creates prices with nil amount' do
      bulk_create

      prices = Spree::Price.for_price_list(price_list)
      expect(prices.pluck(:amount).uniq).to eq([nil])
    end

    it 'creates prices with the specified currency' do
      bulk_create

      prices = Spree::Price.for_price_list(price_list)
      expect(prices.pluck(:currency).uniq).to eq([currency])
    end

    it 'redirects to the edit page with a success notice' do
      bulk_create

      expect(response).to redirect_to(edit_admin_price_list_path(price_list))
      expect(flash[:notice]).to eq(Spree.t(:products_added))
    end

    context 'when some products already have prices' do
      let!(:existing_price) do
        create(:price, variant: product1.master, price_list: price_list, currency: currency, amount: 99.99)
      end

      it 'does not overwrite existing prices' do
        bulk_create

        existing_price.reload
        expect(existing_price.amount).to eq(99.99)
      end

      it 'only creates prices for products without existing prices' do
        expect { bulk_create }.to change(Spree::Price.for_price_list(price_list), :count).by(1)
      end
    end

    context 'with product with multiple variants' do
      let(:product_with_variants) { create(:product, stores: [store]) }
      let!(:variant1) { create(:variant, product: product_with_variants) }
      let!(:variant2) { create(:variant, product: product_with_variants) }

      let(:params) do
        {
          price_list_id: price_list.id,
          product_ids: [product_with_variants.id],
          currency: currency
        }
      end

      it 'creates prices for non-master variants only (skips master)' do
        expect { bulk_create }.to change(Spree::Price.for_price_list(price_list), :count).by(2)
      end
    end

    context 'with product with only master variant' do
      let(:product_master_only) { create(:product, stores: [store]) }

      let(:params) do
        {
          price_list_id: price_list.id,
          product_ids: [product_master_only.id],
          currency: currency
        }
      end

      it 'creates price for master variant' do
        expect { bulk_create }.to change(Spree::Price.for_price_list(price_list), :count).by(1)

        price = Spree::Price.for_price_list(price_list).last
        expect(price.variant).to eq(product_master_only.master)
      end
    end

    context 'with empty product_ids' do
      let(:params) { { price_list_id: price_list.id, product_ids: [], currency: currency } }

      it 'does not create any prices' do
        expect { bulk_create }.not_to change(Spree::Price.for_price_list(price_list), :count)
      end

      it 'redirects to the edit page' do
        bulk_create

        expect(response).to redirect_to(edit_admin_price_list_path(price_list))
      end
    end
  end

  describe 'DELETE #bulk_destroy' do
    subject(:bulk_destroy) { delete :bulk_destroy, params: params }

    let(:product1) { create(:product, stores: [store]) }
    let(:product2) { create(:product, stores: [store]) }
    let(:product3) { create(:product, stores: [store]) }
    let!(:price1) { create(:price, variant: product1.master, price_list: price_list, currency: 'USD', amount: 10.0) }
    let!(:price2) { create(:price, variant: product2.master, price_list: price_list, currency: 'USD', amount: 20.0) }
    let!(:price3) { create(:price, variant: product3.master, price_list: price_list, currency: 'USD', amount: 30.0) }

    let(:params) do
      {
        price_list_id: price_list.id,
        ids: [product1.id, product2.id]
      }
    end

    it 'removes prices for the selected products' do
      expect { bulk_destroy }.to change(Spree::Price.for_price_list(price_list), :count).by(-2)
    end

    it 'does not remove prices for unselected products' do
      bulk_destroy

      expect(Spree::Price.for_price_list(price_list)).to include(price3)
    end

    it 'redirects to the edit page with a success notice' do
      bulk_destroy

      expect(response).to redirect_to(edit_admin_price_list_path(price_list))
      expect(flash[:notice]).to eq(Spree.t(:products_removed))
    end

    context 'with product with multiple variants' do
      let(:product_with_variants) { create(:product, stores: [store]) }
      let!(:variant1) { create(:variant, product: product_with_variants) }
      let!(:variant2) { create(:variant, product: product_with_variants) }
      let!(:variant1_price) { create(:price, variant: variant1, price_list: price_list, currency: 'USD', amount: 10.0) }
      let!(:variant2_price) { create(:price, variant: variant2, price_list: price_list, currency: 'USD', amount: 20.0) }

      let(:params) do
        {
          price_list_id: price_list.id,
          ids: [product_with_variants.id]
        }
      end

      it 'removes prices for all variants of the product' do
        expect { bulk_destroy }.to change(Spree::Price.for_price_list(price_list), :count).by(-2)
      end
    end

    context 'with empty ids' do
      let(:params) { { price_list_id: price_list.id, ids: [] } }

      it 'does not remove any prices' do
        expect { bulk_destroy }.not_to change(Spree::Price.for_price_list(price_list), :count)
      end
    end
  end
end
