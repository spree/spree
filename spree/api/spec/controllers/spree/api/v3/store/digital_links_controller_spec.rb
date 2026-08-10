require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::DigitalLinksController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:order) { create(:order_with_line_items, store: store, customer: user) }
  let(:line_item) { order.line_items.first }
  let(:digital_asset) { create(:digital_asset, variant: line_item.variant) }
  let!(:digital_link) { create(:digital_link, digital_asset: digital_asset, line_item: line_item) }

  describe 'GET #show' do
    it 'redirects to a download URL for a valid token' do
      get :show, params: { token: digital_link.token }

      expect(response).to have_http_status(:found)
      expect(response.location).to be_present
    end

    it 'increments the access counter' do
      expect {
        get :show, params: { token: digital_link.token }
      }.to change { digital_link.reload.access_counter }.by(1)
    end

    it 'publishes a downloaded event' do
      expect_any_instance_of(Spree::DigitalLink).to receive(:publish_event).with('digital_link.downloaded')

      get :show, params: { token: digital_link.token }
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

    # The per-asset override wins over the store setting, so an asset marked
    # freely re-downloadable stays available past the store's click cap.
    context 'when the asset overrides the store click limit' do
      before do
        store.update!(
          preferred_limit_digital_download_count: true,
          preferred_digital_asset_authorized_clicks: 3
        )
        digital_asset.update!(authorized_clicks: 10)
        digital_link.update_column(:access_counter, 3)
      end

      it 'still authorizes the download' do
        get :show, params: { token: digital_link.token }

        expect(response).to have_http_status(:found)
      end
    end

    # The signed URL is a bearer credential; it must not outlive the link.
    context 'when the link lapses sooner than the store download window' do
      before do
        store.update!(
          preferred_limit_digital_download_days: true,
          preferred_digital_asset_authorized_days: 1,
          preferred_digital_asset_link_expire_time: 3600
        )
      end

      it 'clamps the signed URL to the link expiry' do
        digital_link.update_column(:created_at, (1.day - 30.seconds).ago)

        expect_any_instance_of(Spree::DigitalAsset).to receive(:download_url) do |_asset, expires_in:|
          expect(expires_in).to be <= 30.seconds
          'https://storage.example.com/signed'
        end

        get :show, params: { token: digital_link.token }

        expect(response).to have_http_status(:found)
      end
    end

    context 'when the asset has no file to serve' do
      before { digital_asset.attachment.purge }

      it 'returns forbidden without spending a download allowance' do
        expect {
          get :show, params: { token: digital_link.token }
        }.not_to change { digital_link.reload.access_counter }

        expect(response).to have_http_status(:forbidden)
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
      let(:other_digital_asset) { create(:digital_asset, variant: other_line_item.variant) }
      let(:other_digital_link) { create(:digital_link, digital_asset: other_digital_asset, line_item: other_line_item) }

      it 'returns not found' do
        get :show, params: { token: other_digital_link.token }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'still allows access (token is the authentication)' do
        get :show, params: { token: digital_link.token }

        expect(response).to have_http_status(:found)
      end
    end
  end
end
