require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::VariantsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product) { create(:product) }
  let!(:variant) { create(:variant, product: product) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    subject { get :index, as: :json }

    it 'returns variants' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].map { |v| v['id'] }).to include(variant.prefixed_id)
    end

    # The variant picker asks for only the three fields it renders; without
    # this the autocomplete ships prices, stock and media it never shows.
    it 'returns only the requested fields, plus id' do
      get :index, params: { fields: 'product_name,sku,options_text' }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row.keys).to match_array(%w[id product_name sku options_text])
    end

    # The controller's `scope_includes` only applies if `scope` chains onto
    # the base rather than rebuilding the relation. When it does not, prices
    # and stock are read once per listed variant and nothing fails — so the
    # guard is that the cost does not grow with the number of rows.
    it 'reads prices and stock once, not once per variant' do
      counts = [1, 4].map do |variant_count|
        create_list(:variant, variant_count - 1, product: product) if variant_count > 1

        stock_and_price = 0
        subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
          next if payload[:cached]
          next unless payload[:name].to_s.match?(/Price|StockLevel|StockReservation/)

          stock_and_price += 1
        end
        get :index, as: :json
        ActiveSupport::Notifications.unsubscribe(subscription)

        expect(response).to have_http_status(:ok)
        stock_and_price
      end

      expect(counts.last).to eq(counts.first)
    end

    it 'includes the default variant' do
      subject
      returned_ids = json_response['data'].map { |v| v['id'] }
      expect(returned_ids).to include(product.default_variant.prefixed_id)
    end

    it 'returns pagination metadata' do
      subject
      expect(json_response['meta']).to include('page', 'limit', 'count', 'pages')
    end

    context 'with search query' do
      let!(:searchable_variant) { create(:variant, product: product, sku: 'UNIQUE-SKU-12345') }

      it 'filters variants by SKU' do
        get :index, params: { q: { search: 'UNIQUE-SKU' } }, as: :json

        expect(response).to have_http_status(:ok)
        ids = json_response['data'].map { |v| v['id'] }
        expect(ids).to include(searchable_variant.prefixed_id)
      end

      it 'filters variants by product name' do
        get :index, params: { q: { search: product.name[0..4] } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].length).to be >= 1
      end

      it 'returns empty when search has no matches' do
        get :index, params: { q: { search: 'xqzwkj999' } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data']).to eq([])
      end
    end

    context 'without authentication' do
      let(:headers) { {} }

      it 'returns unauthorized' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    subject { get :show, params: { id: variant.prefixed_id }, as: :json }

    it 'returns the variant' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(variant.prefixed_id)
      expect(json_response['sku']).to eq(variant.sku)
    end

    context 'with non-existent variant' do
      it 'returns 404' do
        get :show, params: { id: 'variant_nonexistent' }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
