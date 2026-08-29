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
