require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Products::VariantsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product) { create(:product) }
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
      let(:other_product) { create(:product, store: other_store) }

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
          prices: [{ currency: 'USD', amount: 29.99 }],
          options: [{ name: option_type.name, value: option_value.name }]
        }, as: :json
      }.to change(product.variants, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['sku']).to eq('NEW-SKU-001')
    end

    context 'with nested prices and stock_levels' do
      let!(:stock_location_1) { Spree::StockLocation.first || create(:stock_location) }
      let!(:stock_location_2) { create(:stock_location, name: 'Warehouse 2') }

      it 'creates variant with multi-currency prices and multi-location stock' do
        expect {
          post :create, params: {
            product_id: product.prefixed_id,
            sku: 'MULTI-001',
            options: [{ name: option_type.name, value: 'New Value' }],
            prices: [
              { currency: 'USD', amount: 19.99, compare_at_amount: 24.99 },
              { currency: 'EUR', amount: 17.99 }
            ],
            stock_levels: [
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

        si_1 = created_variant.stock_levels.find_by(stock_location: stock_location_1)
        expect(si_1.count_on_hand).to eq(50)
        expect(si_1.backorderable).to eq(false)

        si_2 = created_variant.stock_levels.find_by(stock_location: stock_location_2)
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

      # The variant's prices are eager-loaded before serialization, so updating
      # an EXISTING base price must be reflected in the response WITHOUT a
      # reload. Asserts on the response body (not a DB re-read) to guard the
      # stale-price bug.
      it 'returns the updated price for an existing currency in the response' do
        existing_currency = variant.prices.base_prices.first.currency

        patch :update, params: {
          product_id: product.prefixed_id,
          id: variant.prefixed_id,
          prices: [
            { currency: existing_currency, amount: 42.50 }
          ]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['price']).to be_present
        expect(json_response['price']['amount'].to_f).to eq(42.50)
      end
    end

    context 'with nested stock_levels' do
      let!(:stock_location) { Spree::StockLocation.first || create(:stock_location) }

      it 'updates stock levels' do
        patch :update, params: {
          product_id: product.prefixed_id,
          id: variant.prefixed_id,
          stock_levels: [
            { stock_location_id: stock_location.prefixed_id, count_on_hand: 99 }
          ]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(variant.reload.stock_levels.find_by(stock_location: stock_location).count_on_hand).to eq(99)
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

  describe 'customs classification' do
    it 'writes and reads back the customs fields' do
      patch :update, params: {
        product_id: product.prefixed_id,
        id: variant.prefixed_id,
        hs_code: '640411',
        country_of_origin: 'vn',
        customs_description: 'Leather footwear'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['hs_code']).to eq('640411')
      expect(json_response['country_of_origin']).to eq('VN')
      expect(json_response['customs_description']).to eq('Leather footwear')
    end

    it 'rejects a malformed hs code' do
      patch :update, params: {
        product_id: product.prefixed_id,
        id: variant.prefixed_id,
        hs_code: '123'
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'seller and delivery profile' do
    let(:seller) { create(:seller, :approved, store: store) }
    let(:profile) { create(:delivery_profile, store: store) }

    # One field each on the wire, resolved on the model. On a master product
    # (the fixture) a write names how this seller's row sells and ships; on an
    # owned product the same write is a no-op — and the client never learns
    # which mode it is in.
    it 'writes and reads back the seller as one field' do
      patch :update, params: {
        product_id: product.prefixed_id,
        id: variant.prefixed_id,
        seller_id: seller.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['seller_id']).to eq(seller.prefixed_id)
    end

    it 'reports the product\'s seller on an owned product and ignores a write there' do
      product.update!(seller: seller)
      other = create(:seller, :approved, store: store)

      patch :update, params: {
        product_id: product.prefixed_id,
        id: variant.prefixed_id,
        seller_id: other.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['seller_id']).to eq(seller.prefixed_id)
      expect(variant.reload[:seller_id]).to be_nil
    end

    it 'writes and reads back the delivery profile as one field' do
      patch :update, params: {
        product_id: product.prefixed_id,
        id: variant.prefixed_id,
        delivery_profile_id: profile.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['delivery_profile_id']).to eq(profile.prefixed_id)
    end

    it 'reports the product\'s profile when the row names none' do
      get :show, params: { product_id: product.prefixed_id, id: variant.prefixed_id }, as: :json

      expect(json_response['delivery_profile_id']).to eq(product.delivery_profile.prefixed_id)
    end

    it 'clears the row\'s profile back to the master\'s' do
      variant.update!(delivery_profile: profile)

      patch :update, params: {
        product_id: product.prefixed_id,
        id: variant.prefixed_id,
        delivery_profile_id: nil
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['delivery_profile_id']).to eq(product.delivery_profile.prefixed_id)
    end

    it 'refuses a seller belonging to another store' do
      foreign = create(:seller, store: create(:store))

      patch :update, params: {
        product_id: product.prefixed_id,
        id: variant.prefixed_id,
        seller_id: foreign.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(variant.reload.association(:seller).reader).to be_nil
    end
  end

  # A review status is an outcome, not a value to assign. Written straight
  # onto a row it would leave a seller looking at a rejected offer with no
  # reason and no trail — the decision is what approve/reject record
  # (docs/plans/6.0-seller-master-catalog-listings.md).
  describe 'writing a review status directly' do
    let(:seller) { create(:seller, :approved, store: store) }
    let!(:offer) { create(:variant, product: product, seller: seller, status: 'draft') }

    it 'drops a rejected status from the payload' do
      patch :update, params: {
        product_id: product.prefixed_id, id: offer.prefixed_id, status: 'rejected'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(offer.reload).to be_draft
      expect(offer.latest_submission).to be_nil
    end

    it 'drops a proposed status from the payload' do
      patch :update, params: {
        product_id: product.prefixed_id, id: offer.prefixed_id, status: 'proposed'
      }, as: :json

      expect(offer.reload).to be_draft
    end

    # The operator's own statuses stay writable — this narrows the review
    # pair only.
    it 'still allows an ordinary status' do
      patch :update, params: {
        product_id: product.prefixed_id, id: offer.prefixed_id, status: 'archived'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(offer.reload).to be_archived
    end

    it 'rejects through the member action, which records the decision' do
      Spree.variant_propose_workflow.call(variant: offer)

      patch :reject, params: {
        product_id: product.prefixed_id, id: offer.prefixed_id, reason: 'Wrong condition'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(offer.reload).to be_rejected
      expect(offer.rejection_reason).to eq('Wrong condition')
    end
  end
end
