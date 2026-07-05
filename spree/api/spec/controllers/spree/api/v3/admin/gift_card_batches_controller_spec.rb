require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::GiftCardBatchesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    let!(:batch) { create(:gift_card_batch, store: store, prefix: 'WELCOME', amount: 50, currency: 'USD', codes_count: 3) }

    it 'returns batches scoped to the current store' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |b| b['id'] }
      expect(ids).to include(batch.prefixed_id)
    end

    it 'excludes batches from other stores' do
      other = create(:gift_card_batch, store: create(:store), prefix: 'OTHER', amount: 5, currency: 'USD', codes_count: 1)

      get :index, as: :json
      ids = json_response['data'].map { |b| b['id'] }
      expect(ids).to include(batch.prefixed_id)
      expect(ids).not_to include(other.prefixed_id)
    end
  end

  describe 'POST #create' do
    let(:base_params) do
      { prefix: 'WELCOME', amount: '25.00', currency: 'USD', codes_count: 5, expires_at: '2030-12-31' }
    end

    it 'creates a batch scoped to the current store and stamps created_by' do
      expect { post :create, params: base_params, as: :json }.to change(Spree::GiftCardBatch, :count).by(1)

      expect(response).to have_http_status(:created)
      batch = Spree::GiftCardBatch.last
      expect(batch.store).to eq(store)
      expect(batch.created_by_id).to eq(admin_user.id)
      expect(batch.prefix).to eq('WELCOME')
      expect(batch.codes_count).to eq(5)
    end

    it 'auto-generates the gift cards inline for small batches' do
      expect { post :create, params: base_params.merge(codes_count: 3), as: :json }
        .to change(Spree::GiftCard, :count).by(3)

      batch = Spree::GiftCardBatch.last
      expect(batch.gift_cards.count).to eq(3)
      expect(batch.gift_cards.all? { |g| g.code.start_with?('welcome') }).to be(true)
      expect(batch.gift_cards.all? { |g| g.currency == 'USD' && g.amount == 25 }).to be(true)
    end

    it 'returns 422 when prefix is blank' do
      post :create, params: base_params.merge(prefix: ''), as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 when codes_count is zero' do
      post :create, params: base_params.merge(codes_count: 0), as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 when codes_count exceeds the configured cap' do
      allow(Spree::Config).to receive(:[]).and_call_original
      allow(Spree::Config).to receive(:[]).with(:gift_card_batch_limit).and_return(10)

      post :create, params: base_params.merge(codes_count: 11), as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'GET #show' do
    let!(:batch) { create(:gift_card_batch, store: store, prefix: 'WELCOME', amount: 50, currency: 'USD', codes_count: 2) }

    it 'returns the batch' do
      get :show, params: { id: batch.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(batch.prefixed_id)
      expect(json_response['prefix']).to eq('WELCOME')
      expect(json_response['codes_count']).to eq(2)
    end

    it 'returns 404 for a batch from another store' do
      other = create(:gift_card_batch, store: create(:store), prefix: 'OTHER', amount: 5, currency: 'USD', codes_count: 1)

      get :show, params: { id: other.prefixed_id }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
