require 'spec_helper'

describe 'API v2 Errors spec', type: :request do
  context 'record not found' do
    before { get '/api/v2/storefront/products/product-that-doesn-t-exist' }

    it 'returns proper error message' do
      expect(response.status).to eq(404)
      expect(json_response['error']).to eq('The resource you were looking for could not be found.')
    end
  end

  context 'authorization failure' do
    let(:user) { create(:user) }
    let(:another_user) { create(:user) }
    let!(:order) { create(:order, user: another_user) }

    include_context 'API v2 tokens'

    before do
      allow_any_instance_of(Spree::Api::V2::Storefront::CartController).to receive(:spree_current_order).and_return(order)
      patch '/api/v2/storefront/cart/empty', headers: headers_bearer
    end

    it 'returns proper error message' do
      expect(response.status).to eq(403)
      expect(json_response['error']).to eq('You are not authorized to access this page.')
    end

    it 'calls error handler' do
      expect(Rails.error).to receive(:report).with(
        instance_of(CanCan::AccessDenied),
        context: { user_id: user.id },
        source: 'spree.api'
      )

      patch '/api/v2/storefront/cart/empty', headers: headers_bearer
    end
  end

  context 'expired token failure' do
    let(:user) { create(:user) }
    let(:headers) { headers_bearer }

    include_context 'API v2 tokens'

    before do
      token.expires_in = -1
      token.save
      get '/api/v2/storefront/account', headers: headers
    end

    it_behaves_like 'returns 401 HTTP status'
  end
end
