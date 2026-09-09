require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PriceLists::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:price_list) { create(:price_list, store: store) }

  before { request.headers.merge!(headers) }

  it_behaves_like 'a product membership surface' do
    let(:parent_route_params) { { price_list_id: price_list.prefixed_id } }
    let(:foreign_parent_route_params) do
      { price_list_id: create(:price_list, store: create(:store)).prefixed_id }
    end

    def seed_member(product)
      price_list.add_products([product.id])
    end

    def member_products
      price_list.products.reload.to_a
    end
  end

  describe 'GET #index' do
    let(:product) { create(:product, store: store, price: 100) }

    before do
      price_list.add_products([product.id])
      price_list.bulk_update_prices(price_list.prices.where(currency: 'USD', min_quantity: 1).map { |row| { id: row.id, amount: '60' } })
      create(:price, variant: product.default_variant, price_list: price_list, currency: 'USD', min_quantity: 24, amount: 50)
    end

    it 'lists plain products without the price reading' do
      get :index, params: { price_list_id: price_list.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].first).not_to have_key('price_list_variants')
    end

    # The page renders 25 rows with every variant priced. Resolving the
    # product's own figure through the buy box would ask about stock per
    # variant — 174 stock queries on a page that never shows stock — so the
    # count is pinned rather than left to whichever variant reader a future
    # edit reaches for (docs/plans/6.0-volume-pricing.md).
    it 'prices the page without a query per variant' do
      3.times do
        product = create(:product, store: store)
        create(:variant, product: product)
        price_list.add_products([product.id])
      end

      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name].to_s =~ /SCHEMA|CACHE|TRANSACTION/ }
      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
        get :index, params: { price_list_id: price_list.prefixed_id, expand: 'price_list_price' }, as: :json
      end

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to be >= 3
      expect(queries).to be < 20
    end

    # The card renders a name and a thumbnail, and the picker reads ids. A
    # full product payload per row is what made this page slow, so the shape
    # is pinned rather than left to whatever the admin serializer grows.
    it 'sends only what the membership card and the picker read' do
      get :index, params: { price_list_id: price_list.prefixed_id }, as: :json

      expect(json_response['data'].first.keys).to match_array(%w[id name thumbnail_url])
    end

    it 'adds only the price reading when expanded' do
      get :index, params: { price_list_id: price_list.prefixed_id, expand: 'price_list_price' }, as: :json

      expect(json_response['data'].first.keys).
        to match_array(%w[id name thumbnail_url price_list_variants])
    end

    it 'prices each variant with its ladder when expanded' do
      get :index, params: { price_list_id: price_list.prefixed_id, expand: 'price_list_price' }, as: :json

      row = json_response['data'].first
      variant_row = row['price_list_variants'].first
      expect(variant_row['id']).to eq(product.default_variant.prefixed_id)
      expect(variant_row['break_count']).to eq(1)
      expect(variant_row['tiers'].first['min_quantity']).to eq(24)
    end
  end

  describe 'POST #create' do
    it 'materializes a placeholder price per variant and store currency' do
      product = create(:product, store: store)

      post :create,
           params: { price_list_id: price_list.prefixed_id, product_ids: [product.prefixed_id] },
           as: :json

      expect(response).to have_http_status(:created)
      placeholders = price_list.prices.where(variant_id: product.variants.ids)
      expect(placeholders).to be_present
      expect(placeholders.pluck(:amount)).to all(be_nil)
    end
  end

  describe 'DELETE #destroy' do
    # A product joins the scope once per price row (variant x currency), so
    # the count must still say 1 per product, not per row.
    it 'counts products, not price rows' do
      product = create(:product, store: store)
      price_list.add_products([product.id])
      price_list.prices.update_all(amount: 10)

      delete :destroy,
             params: { price_list_id: price_list.prefixed_id, product_ids: [product.prefixed_id] },
             as: :json

      expect(json_response['removed_count']).to eq(1)
      expect(price_list.prices.where(variant_id: product.variants.ids)).to be_empty
    end
  end
end
