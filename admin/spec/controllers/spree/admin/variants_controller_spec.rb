require 'spec_helper'

RSpec.describe Spree::Admin::VariantsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:product) { create(:product, name: 'Shoes', stores: [store]) }
  let!(:variant) { create(:variant, product: product) }
  let(:tax_category) { create(:tax_category) }

  describe 'GET #search' do
    context 'JSON format' do
      subject(:search) { get :search, params: params, format: :json }

      let(:params) { { q: q } }

      context 'when query is blank' do
        let(:q) { '' }

        it 'returns an empty response' do
          search
        end
      end

      context 'when query is less than 3 characters' do
        let(:q) { 'sh' }

        it 'returns an empty response' do
          search
        end
      end

      context 'when query is valid' do
        let(:q) { 'shoe' }

        it 'returns the variants' do
          search

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq([{ 'id' => variant.id, 'name' => variant.descriptive_name }])
        end
      end
    end
  end

  describe 'POST #search' do
    subject(:search) { get :search, params: params, format: :turbo_stream }

    let(:params) { { q: q } }

    context 'when query is blank' do
      let(:q) { '' }

      it 'returns an empty response' do
        search

        expect(response).to have_http_status(:ok)
        expect(response.body).to be_blank
      end
    end

    context 'when query is less than 3 characters' do
      let(:q) { 'sh' }

      it 'returns an empty response' do
        search

        expect(response).to have_http_status(:ok)
        expect(response.body).to be_blank
      end
    end

    context 'when query is valid' do
      let(:q) { 'shoe' }

      let!(:variant_2) { create(:variant, product: product) }
      let!(:variant_3) { create(:variant, product: product) }

      let!(:product_2) { create(:product, name: 'Shirt', stores: [store]) }
      let!(:variant_4) { create(:variant, product: product_2) }

      it 'responds with searched variants' do
        search

        expect(response).to have_http_status(:ok)
        expect(response).to render_template(partial: 'spree/admin/variants/_search_results')
        expect(assigns(:variants)).to match_array([variant, variant_2, variant_3])
      end

      context 'when omit_ids parameter is present' do
        let(:params) { { q: q, omit_ids: "#{variant.id},#{variant_2.id}" } }

        it 'excludes the variants with the given ids' do
          search

          expect(response).to have_http_status(:ok)
          expect(response).to render_template(partial: 'spree/admin/variants/_search_results')
          expect(assigns(:variants)).to match_array([variant_3])
        end
      end

      context 'when limit parameter is present' do
        let(:params) { { q: q, limit: 2 } }

        it 'limits the number of variants returned' do
          search

          expect(response).to have_http_status(:ok)
          expect(response).to render_template(partial: 'spree/admin/variants/_search_results')

          expect(assigns(:variants).size).to eq(2)
          expect(assigns(:variants)).to match_array([variant, variant_2])
        end
      end
    end
  end

  describe 'GET #edit' do
    subject(:edit) { get :edit, params: { id: variant.to_param, product_id: product.slug } }

    it 'renders the variant edit page' do
      edit
      expect(response).to render_template(:edit)
    end
  end

  describe 'PUT #update' do
    let(:variant_params) do
      {
        id: variant.to_param,
        product_id: product.slug,
        variant: {
          sku: 'SKU123456',
          barcode: '1234567890',
          width: 10,
          height: 10,
          depth: 10,
          weight: 10,
          dimensions_unit: 'cm',
          weight_unit: 'kg',
          tax_category_id: tax_category.id
        }
      }
    end

    it 'should update the variant' do
      put :update, params: variant_params
      expect(response).to redirect_to(spree.edit_admin_product_variant_path(product, variant))

      variant.reload

      expect(variant.sku).to eq('SKU123456')
      expect(variant.barcode).to eq('1234567890')
      expect(variant.width).to eq(10)
      expect(variant.height).to eq(10)
      expect(variant.depth).to eq(10)
      expect(variant.weight).to eq(10)
      expect(variant.dimensions_unit).to eq('cm')
      expect(variant.weight_unit).to eq('kg')
      expect(variant.tax_category).to eq(tax_category)
    end

    context 'with multiple currencies' do
      let(:variant_params) do
        {
          id: variant.to_param,
          product_id: product.slug,
          variant: {
            prices_attributes: {
              '0': {
                id: variant.prices.first.id,
                amount: 10,
                currency: 'USD'
              },
              '1': {
                amount: 20,
                currency: 'EUR'
              },
              '2': {
                amount: '',
                currency: 'GBP'
              }
            }
          }
        }
      end

      it 'should create 1 price, and update 1 price' do
        expect { put :update, params: variant_params }.to change(Spree::Price, :count).by(1)

        variant.reload
        expect(variant.prices.count).to eq(2)
        expect(variant.price_in('USD').amount).to eq(10)
        expect(variant.price_in('EUR').amount).to eq(20)
        expect(variant.price_in('GBP').amount).to be_nil
      end
    end

    context 'with multiple stock locations' do
      let!(:stock_location) { Spree::StockLocation.first || create(:stock_location) }
      let!(:stock_location2) { create(:stock_location) }
      let!(:stock_item) { create(:stock_item, stock_location: stock_location, variant: variant, count_on_hand: 10) }

      let(:variant_params) do
        {
          id: variant.to_param,
          product_id: product.slug,
          variant: {
            stock_items_attributes: {
              '0': { id: stock_item.id, count_on_hand: 20, backorderable: false, stock_location_id: stock_location.id },
              '1': { count_on_hand: 30, backorderable: true, stock_location_id: stock_location2.id }
            }
          }
        }
      end

      it 'should create 1 stock item, and update 1 stock item' do
        expect { put :update, params: variant_params }.to change(Spree::StockItem, :count).by(1)

        variant.reload
        expect(variant.stock_items.count).to eq(2)
        expect(variant.stock_items.first.count_on_hand).to eq(20)
        expect(variant.stock_items.first.backorderable).to eq(false)
        expect(variant.stock_items.last.count_on_hand).to eq(30)
        expect(variant.stock_items.last.backorderable).to eq(true)
      end
    end

    context 'disabling track inventory' do
      let(:variant_params) do
        {
          id: variant.to_param,
          product_id: product.slug,
          variant: { track_inventory: '0' }
        }
      end

      it 'sets the track inventory to false' do
        expect(variant.track_inventory).to eq(true)
        put :update, params: variant_params
        variant.reload
        expect(variant.track_inventory).to eq(false)
        expect(variant.stock_items.first.count_on_hand).to eq(0)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'should destroy the variant' do
      delete :destroy, params: { product_id: product.slug, id: variant.to_param }
      expect(response).to redirect_to(spree.edit_admin_product_path(product))
    end
  end
end
