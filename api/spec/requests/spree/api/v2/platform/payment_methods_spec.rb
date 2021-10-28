require 'spec_helper'

describe 'Platform API v2 Payment Methods', type: :request do
  include_context 'API v2 tokens'
  include_context 'Platform API v2'

  let!(:store) { Spree::Store.default }
  let(:resource_a) { create(:payment_method, stores: [store]) }
  let(:resource_b) { create(:payment_method, stores: [store]) }
  let(:resource_c) { create(:payment_method, stores: [store]) }
  let(:resource_d) { create(:payment_method, stores: [store]) }

  let(:bearer_token) { { 'Authorization' => valid_authorization } }

  describe 'payment_methods#reposition' do
    context 'with no params' do
      let(:params) { }

      before do
        patch "/api/v2/platform/payment_methods/#{resource_a.id}/reposition", headers: bearer_token, params: params
      end

      it_behaves_like 'returns 422 HTTP status'
    end

    context 'with correct params' do
      let(:params) { { new_position_idx: 0 } }

      before do
        patch "/api/v2/platform/payment_methods/#{resource_d.id}/reposition", headers: bearer_token, params: params
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'repositions resource from position 4 to position 1' do
        # acts_as_list is not zero indexed so moving to
        # position 0 results in a saved postiton at 1.
        resource_d.reload
        expect(resource_d.position).to eq(1)
      end
    end

    context 'with correct params' do
      let(:params) { { new_position_idx: 3 } }

      before do
        patch "/api/v2/platform/payment_methods/#{resource_a.id}/reposition", headers: bearer_token, params: params
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'moves item from position 1 to position 4' do
        # acts_as_list is not zero indexed so moving to
        # position 3 results in a saved postiton at 4.
        resource_a.reload
        expect(resource_a.position).to eq(4)
      end
    end
  end
end
