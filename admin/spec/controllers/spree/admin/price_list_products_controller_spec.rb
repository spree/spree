require 'spec_helper'

RSpec.describe Spree::Admin::PriceListProductsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:price_list) { create(:price_list, store: store) }

  describe 'GET #index' do
    subject(:index) { get :index, params: { price_list_id: price_list.to_param } }

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
    subject(:bulk_new_action) { get :bulk_new, params: { price_list_id: price_list.to_param } }

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
    subject(:bulk_create) { post :bulk_create, params: params, format: :turbo_stream }

    let(:product1) { create(:product, stores: [store]) }
    let(:product2) { create(:product, stores: [store]) }

    let(:params) do
      {
        price_list_id: price_list.to_param,
        ids: [product1.id, product2.id]
      }
    end

    it 'creates price records for all variants of the products in all currencies' do
      # 2 products * 3 currencies = 6 prices
      expect { bulk_create }.to change(Spree::Price.for_price_list(price_list), :count).by(6)
    end

    it 'creates prices with nil amount' do
      bulk_create

      prices = Spree::Price.for_price_list(price_list)
      expect(prices.pluck(:amount).uniq).to eq([nil])
    end

    it 'creates prices for all supported currencies' do
      bulk_create

      prices = Spree::Price.for_price_list(price_list).where(variant: product1.master)
      expect(prices.pluck(:currency)).to match_array(store.supported_currencies_list.map(&:iso_code))
    end

    it 'sets a flash success message' do
      bulk_create

      expect(flash[:success]).to eq(Spree.t(:products_added))
    end

    context 'when some products already have prices' do
      let!(:existing_price) do
        create(:price, variant: product1.master, price_list: price_list, currency: 'USD', amount: 99.99)
      end

      it 'does not overwrite existing prices' do
        bulk_create

        existing_price.reload
        expect(existing_price.amount).to eq(99.99)
      end

      it 'only creates prices for currencies without existing prices' do
        # product1 already has USD, so only EUR and GBP are created for product1
        # product2 gets all 3 currencies
        # Total: 2 (product1: EUR, GBP) + 3 (product2: USD, EUR, GBP) = 5
        expect { bulk_create }.to change(Spree::Price.for_price_list(price_list), :count).by(5)
      end
    end

    context 'with product with multiple variants' do
      let(:product_with_variants) { create(:product, stores: [store]) }
      let!(:variant1) { create(:variant, product: product_with_variants) }
      let!(:variant2) { create(:variant, product: product_with_variants) }

      let(:params) do
        {
          price_list_id: price_list.to_param,
          ids: [product_with_variants.id]
        }
      end

      it 'creates prices for non-master variants only (skips master)' do
        # 2 variants * 3 currencies = 6 prices
        expect { bulk_create }.to change(Spree::Price.for_price_list(price_list), :count).by(6)
      end
    end

    context 'with product with only master variant' do
      let(:product_master_only) { create(:product, stores: [store]) }

      let(:params) do
        {
          price_list_id: price_list.to_param,
          ids: [product_master_only.id]
        }
      end

      it 'creates price for master variant in all currencies' do
        # 1 variant * 3 currencies = 3 prices
        expect { bulk_create }.to change(Spree::Price.for_price_list(price_list), :count).by(3)

        prices = Spree::Price.for_price_list(price_list).where(variant: product_master_only.master)
        expect(prices.count).to eq(3)
      end
    end

    context 'with empty ids' do
      let(:params) { { price_list_id: price_list.to_param, ids: [] } }

      it 'does not create any prices' do
        expect { bulk_create }.not_to change(Spree::Price.for_price_list(price_list), :count)
      end
    end
  end

  describe 'DELETE #bulk_destroy' do
    subject(:bulk_destroy) { delete :bulk_destroy, params: params, format: :turbo_stream }

    let(:product1) { create(:product, stores: [store]) }
    let(:product2) { create(:product, stores: [store]) }
    let(:product3) { create(:product, stores: [store]) }
    let!(:price1) { create(:price, variant: product1.master, price_list: price_list, currency: 'USD', amount: 10.0) }
    let!(:price2) { create(:price, variant: product2.master, price_list: price_list, currency: 'USD', amount: 20.0) }
    let!(:price3) { create(:price, variant: product3.master, price_list: price_list, currency: 'USD', amount: 30.0) }

    let(:params) do
      {
        price_list_id: price_list.to_param,
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

    context 'with product with multiple variants' do
      let(:product_with_variants) { create(:product, stores: [store]) }
      let!(:variant1) { create(:variant, product: product_with_variants) }
      let!(:variant2) { create(:variant, product: product_with_variants) }
      let!(:variant1_price) { create(:price, variant: variant1, price_list: price_list, currency: 'USD', amount: 10.0) }
      let!(:variant2_price) { create(:price, variant: variant2, price_list: price_list, currency: 'USD', amount: 20.0) }

      let(:params) do
        {
          price_list_id: price_list.to_param,
          ids: [product_with_variants.id]
        }
      end

      it 'removes prices for all variants of the product' do
        expect { bulk_destroy }.to change(Spree::Price.for_price_list(price_list), :count).by(-2)
      end
    end

    context 'with empty ids' do
      let(:params) { { price_list_id: price_list.to_param, ids: [] } }

      it 'does not remove any prices' do
        expect { bulk_destroy }.not_to change(Spree::Price.for_price_list(price_list), :count)
      end
    end
  end
end
