require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::DigitalLinksController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:product) { create(:product, store: store) }
  let(:order) { create(:order_with_line_items, store: store) }
  let(:line_item) { order.line_items.first }
  let(:digital_asset) { create(:digital_asset, variant: line_item.variant) }
  let!(:digital_link) { create(:digital_link, digital_asset: digital_asset, line_item: line_item) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the links for the store' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |l| l['id'] }).to include(digital_link.prefixed_id)
    end

    it 'excludes links from another store' do
      other_order = create(:order_with_line_items, store: create(:store))
      other_item = other_order.line_items.first
      other_link = create(:digital_link, digital_asset: create(:digital_asset, variant: other_item.variant),
                                         line_item: other_item)

      get :index

      expect(json_response['data'].map { |l| l['id'] }).not_to include(other_link.prefixed_id)
    end
  end

  describe 'PATCH #reset' do
    before { digital_link.update_column(:access_counter, 5) }

    it 'gives the download allowance back' do
      patch :reset, params: { id: digital_link.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['access_counter']).to eq(0)
      expect(digital_link.reload.access_counter).to eq(0)
    end

    it 'restarts the expiry clock' do
      store.update!(preferred_limit_digital_download_days: true, preferred_digital_asset_authorized_days: 1)
      digital_link.update_column(:created_at, 5.days.ago)
      expect(digital_link.reload).to be_expired

      patch :reset, params: { id: digital_link.prefixed_id }

      expect(digital_link.reload).not_to be_expired
    end

    it 'does not reset a link from another store' do
      other_order = create(:order_with_line_items, store: create(:store))
      other_item = other_order.line_items.first
      other_link = create(:digital_link, digital_asset: create(:digital_asset, variant: other_item.variant),
                                         line_item: other_item)

      patch :reset, params: { id: other_link.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end
  end

  # Reset is a write: the catalog grants :manage for write_orders, so no
  # per-action mapping is needed — but the deny path is worth pinning.
  describe 'scope enforcement' do
    it 'denies reset to a read-only key' do
      read_key = create(:api_key, :secret, store: store, scopes: ['read_orders'])
      request.headers['x-spree-api-key'] = read_key.plaintext_token

      patch :reset, params: { id: digital_link.prefixed_id }

      expect(response.status).to be_in([401, 403])
    end

    it 'allows reset with a write key' do
      write_key = create(:api_key, :secret, store: store, scopes: ['write_orders', 'read_orders'])
      request.headers['x-spree-api-key'] = write_key.plaintext_token

      patch :reset, params: { id: digital_link.prefixed_id }

      expect(response).to have_http_status(:ok)
    end
  end
end
