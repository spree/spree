require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::DigitalsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:order) { create(:order_with_line_items, store: store, user: user) }
  let(:line_item) { order.line_items.first }
  let(:digital) { create(:digital, variant: line_item.variant) }
  let!(:digital_link) { create(:digital_link, digital: digital, line_item: line_item) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #show' do
    it 'sends the file for a valid token' do
      get :show, params: { token: digital_link.token }

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Disposition']).to include('thinking-cat.jpg')
    end

    it 'increments the access counter' do
      expect {
        get :show, params: { token: digital_link.token }
      }.to change { digital_link.reload.access_counter }.by(1)
    end

    context 'when link is expired' do
      before do
        store.update!(
          preferred_limit_digital_download_days: true,
          preferred_digital_asset_authorized_days: 1
        )
        digital_link.update_column(:created_at, 2.days.ago)
      end

      it 'returns forbidden with digital_link_expired code' do
        get :show, params: { token: digital_link.token }

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['code']).to eq('digital_link_expired')
        expect(json_response['error']['message']).to be_present
      end
    end

    context 'when download limit is exceeded' do
      before do
        store.update!(
          preferred_limit_digital_download_count: true,
          preferred_digital_asset_authorized_clicks: 3
        )
        digital_link.update_column(:access_counter, 3)
      end

      it 'returns forbidden with digital_link_expired code' do
        get :show, params: { token: digital_link.token }

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['code']).to eq('digital_link_expired')
      end
    end

    context 'with invalid token' do
      it 'returns not found' do
        get :show, params: { token: 'invalid_token' }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with token from another store' do
      let(:other_store) { create(:store) }
      let(:other_order) { create(:order_with_line_items, store: other_store) }
      let(:other_line_item) { other_order.line_items.first }
      let(:other_digital) { create(:digital, variant: other_line_item.variant) }
      let(:other_digital_link) { create(:digital_link, digital: other_digital, line_item: other_line_item) }

      it 'returns not found' do
        get :show, params: { token: other_digital_link.token }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        get :show, params: { token: digital_link.token }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
