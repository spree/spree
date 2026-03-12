require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Products::VariantsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product) { create(:product, stores: [store]) }
  let!(:variant) { create(:variant, product: product) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns variants for the product' do
      get :index, params: { product_id: product.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      ids = json_response['data'].map { |v| v['id'] }
      expect(ids).to include(variant.prefixed_id)
    end

    context 'with product from another store' do
      let(:other_store) { create(:store) }
      let(:other_product) { create(:product, stores: [other_store]) }

      it 'returns 404' do
        get :index, params: { product_id: other_product.prefixed_id }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET #show' do
    it 'returns the variant' do
      get :show, params: { product_id: product.prefixed_id, id: variant.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(variant.prefixed_id)
      expect(json_response['sku']).to eq(variant.sku)
    end
  end

  describe 'POST #create' do
    let(:option_type) { create(:option_type) }
    let(:option_value) { create(:option_value, option_type: option_type) }

    before { product.option_types << option_type }

    it 'creates a variant with options' do
      expect {
        post :create, params: {
          product_id: product.prefixed_id,
          sku: 'NEW-SKU-001',
          price: 29.99,
          options: [{ name: option_type.name, value: option_value.name }]
        }, as: :json
      }.to change(product.variants, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['sku']).to eq('NEW-SKU-001')
    end

    context 'with nested prices and stock_items' do
      let!(:stock_location_1) { Spree::StockLocation.first || create(:stock_location) }
      let!(:stock_location_2) { create(:stock_location, name: 'Warehouse 2') }

      it 'creates variant with multi-currency prices and multi-location stock' do
        expect {
          post :create, params: {
            product_id: product.prefixed_id,
            sku: 'MULTI-001',
            price: 19.99,
            options: [{ name: option_type.name, value: 'New Value' }],
            prices: [
              { currency: 'USD', amount: 19.99, compare_at_amount: 24.99 },
              { currency: 'EUR', amount: 17.99 }
            ],
            stock_items: [
              { stock_location_id: stock_location_1.prefixed_id, count_on_hand: 50, backorderable: false },
              { stock_location_id: stock_location_2.prefixed_id, count_on_hand: 10, backorderable: true }
            ]
          }, as: :json
        }.to change(product.variants, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['sku']).to eq('MULTI-001')

        created_variant = Spree::Variant.find_by(sku: 'MULTI-001')
        expect(created_variant.prices.find_by(currency: 'USD').amount.to_f).to eq(19.99)
        expect(created_variant.prices.find_by(currency: 'USD').compare_at_amount.to_f).to eq(24.99)
        expect(created_variant.prices.find_by(currency: 'EUR').amount.to_f).to eq(17.99)

        si_1 = created_variant.stock_items.find_by(stock_location: stock_location_1)
        expect(si_1.count_on_hand).to eq(50)
        expect(si_1.backorderable).to eq(false)

        si_2 = created_variant.stock_items.find_by(stock_location: stock_location_2)
        expect(si_2.count_on_hand).to eq(10)
        expect(si_2.backorderable).to eq(true)
      end
    end

    context 'with invalid params' do
      it 'returns validation errors' do
        post :create, params: {
          product_id: product.prefixed_id,
          sku: variant.sku # duplicate SKU
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
      end
    end
  end

  describe 'PATCH #update' do
    it 'updates the variant sku' do
      patch :update, params: {
        product_id: product.prefixed_id,
        id: variant.prefixed_id,
        sku: 'UPDATED-SKU'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['sku']).to eq('UPDATED-SKU')
      expect(variant.reload.sku).to eq('UPDATED-SKU')
    end

    context 'with nested prices' do
      it 'updates variant prices' do
        patch :update, params: {
          product_id: product.prefixed_id,
          id: variant.prefixed_id,
          prices: [
            { currency: 'GBP', amount: 15.99 }
          ]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(variant.reload.prices.find_by(currency: 'GBP').amount.to_f).to eq(15.99)
      end
    end

    context 'with nested stock_items' do
      let!(:stock_location) { Spree::StockLocation.first || create(:stock_location) }

      it 'updates stock levels' do
        patch :update, params: {
          product_id: product.prefixed_id,
          id: variant.prefixed_id,
          stock_items: [
            { stock_location_id: stock_location.prefixed_id, count_on_hand: 99 }
          ]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(variant.reload.stock_items.find_by(stock_location: stock_location).count_on_hand).to eq(99)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'soft-deletes the variant' do
      delete :destroy, params: {
        product_id: product.prefixed_id,
        id: variant.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(variant.reload.deleted_at).not_to be_nil
    end
  end
end
