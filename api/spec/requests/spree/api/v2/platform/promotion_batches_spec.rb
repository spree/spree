require 'spec_helper'

describe 'Promotion API v2 spec', type: :request do
  include_context 'API v2 tokens'
  include_context 'Platform API v2'

  let(:bearer_token) { { 'Authorization' => valid_authorization } }

  describe 'promotion_batches#index' do
    before { create(:promotion_batch) }

    before { get '/api/v2/platform/promotion_batches', headers: bearer_token }

    it_behaves_like 'returns 200 HTTP status'

    it 'returns a list of promotion batches' do
      expect(json_response['data'].count).to eq(1)
      expect(json_response['data'].first).to have_type('promotion_batch')
    end
  end

  describe 'promotion_batches#create' do
    before { post '/api/v2/platform/promotion_batches', params: params, headers: bearer_token }

    let(:template_promotion) { create(:promotion) }

    let(:params) do
      {
        promotion_batch: {
          template_promotion_id: template_promotion.id,
          amount: 10,
          random_characters: 5,
          prefix: 'MYPROMO_'
        }
      }
    end

    it_behaves_like 'returns 200 HTTP status'

    it 'creates a promotion batch' do
      expect(Spree::PromotionBatch.count).to eq(1)
      promotion_batch = Spree::PromotionBatch.first
      expect(promotion_batch.template_promotion).to eq(template_promotion)
      expect(promotion_batch.codes.size).to eq(10)
      expect(promotion_batch.codes.first).to start_with('MYPROMO_')
    end
  end

  describe 'promotion_batches#import' do
    before { post '/api/v2/platform/promotion_batches/import', params: params, headers: bearer_token }

    let(:template_promotion) { create(:promotion) }

    let(:params) do
      {
        promotion_batch: {
          template_promotion_id: template_promotion.id,
          codes: ['ABCD', 'EFGH']
        }
      }
    end

    it_behaves_like 'returns 200 HTTP status'

    it 'creates a promotion batch' do
      expect(Spree::PromotionBatch.count).to eq(1)
      promotion_batch = Spree::PromotionBatch.first
      expect(promotion_batch.template_promotion).to eq(template_promotion)
      expect(promotion_batch.codes).to eq(['ABCD', 'EFGH'])
    end
  end
end
