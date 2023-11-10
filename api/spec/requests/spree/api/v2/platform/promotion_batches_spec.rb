require 'spec_helper'

describe 'Promotion API v2 spec', type: :request do
  include_context 'API v2 tokens'
  include_context 'Platform API v2'

  let(:bearer_token) { { 'Authorization' => valid_authorization } }

  describe 'promotion_batches#create' do
    context 'with valid params' do
      before { post '/api/v2/platform/promotion_batches', params: params, headers: bearer_token }
    
      let(:new_promotion_batch_attributes) do
        {
          template_promotion_id: nil
        }
      end

      let(:params) { { promotion_batch: new_promotion_batch_attributes } }

      it 'creates and returns a promotion batch' do
        expect(json_response['data']).to have_relationship(:template_promotion).with_data(nil)
      end
    end

    context 'when assigning a non-existing template' do
      before { post '/api/v2/platform/promotion_batches', params: params, headers: bearer_token }
    
      let(:new_promotion_batch_attributes) do
        {
          template_promotion_id: 123
        }
      end
  
      let(:params) { { promotion_batch: new_promotion_batch_attributes } }
  
      it 'does not create and returns an error' do
        expect(json_response.has_key?('error')).to eq(true)
      end
    end
  end

  describe 'promotion_batches#update' do
    context 'with valid params' do
      before { put "/api/v2/platform/promotion_batches/#{existing_promotion_batch.id}", params: params, headers: bearer_token }

      let(:existing_promotion) { create(:promotion) }
      let(:existing_promotion_batch) { create(:promotion_batch, template_promotion_id: nil) }

      let(:update_promotion_attributes) do
        {
          template_promotion_id: existing_promotion.id
        }
      end

      let(:params) { { promotion_batch: update_promotion_attributes } }

      it 'updates and returns a promotion batch' do
        expect(json_response['data']).to have_relationship(:template_promotion).with_data({ 'id' => existing_promotion.id.to_s, 'type' => 'promotion' })
      end
    end

    context 'when trying to override an assigned template' do
      before do
        existing_promotion
        other_existing_promotion
        existing_promotion_batch
        put "/api/v2/platform/promotion_batches/#{existing_promotion_batch.id}", params: params, headers: bearer_token
      end

      let(:existing_promotion) { create(:promotion) }
      let(:other_existing_promotion) { create(:promotion) }
      let(:existing_promotion_batch) { create(:promotion_batch, template_promotion: existing_promotion) }

      let(:update_promotion_attributes) do
        {
          template_promotion_id: other_existing_promotion.id
        }
      end

      let(:params) { { promotion_batch: update_promotion_attributes } }

      it 'does not update and returns an error' do
        expect(json_response.dig(:errors, :template_promotion_id)).to eq(['Template promotion has already been assigned!'])
      end
    end
  end

  describe 'promotion_batches#populate' do
    context 'with valid params' do
      before { post "/api/v2/platform/promotion_batches/#{existing_promotion_batch.id}/populate", params: params, headers: bearer_token }

      let(:existing_promotion_batch) { create(:promotion_batch) }

      let(:params) do
        {
          batch_size: 2,
          code: {
              affix: 'prefix'
          },
          affix_content: 'BLACKWEEK_',
          forbidden_phrases: 'forbidden phrases',
          random_part_bytes: 4
        }
      end

      it 'is successful' do
        expect(json_response[:message]).to eq('Promotion Batch is being populated.')
      end
    end
  end
end
