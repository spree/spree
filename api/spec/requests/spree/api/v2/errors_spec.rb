require 'spec_helper'

describe 'API v2 Errors spec', type: :request do
  context 'record not found' do
    before { get '/api/v2/storefront/products/product-that-doesn-t-exist' }

    it_behaves_like 'returns 404 HTTP status'

    it 'returns proper error message' do
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

    it_behaves_like 'returns 403 HTTP status'

    it 'returns proper error message' do
      expect(json_response['error']).to eq('You are not authorized to access this page.')
    end
  end
end
