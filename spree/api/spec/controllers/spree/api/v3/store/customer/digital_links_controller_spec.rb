require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Customer::DigitalLinksController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:order) { create(:completed_order_with_totals, store: store, customer: user) }
  let(:line_item) { order.line_items.first }
  let(:digital_asset) { create(:digital_asset, variant: line_item.variant) }
  let!(:digital_link) { create(:digital_link, digital_asset: digital_asset, line_item: line_item) }

  describe 'GET #index' do
    context 'when signed in' do
      before { request.headers.merge!(bearer_headers) }

      it 'lists everything the customer can download' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].map { |l| l['id'] }).to include(digital_link.prefixed_id)
      end

      it 'includes a download url for each link' do
        get :index

        expect(json_response['data'].first['download_url']).to include(digital_link.token)
      end

      it 'excludes links belonging to another customer' do
        other_order = create(:completed_order_with_totals, store: store)
        other_item = other_order.line_items.first
        other_link = create(:digital_link,
                            digital_asset: create(:digital_asset, variant: other_item.variant),
                            line_item: other_item)

        get :index

        expect(json_response['data'].map { |l| l['id'] }).not_to include(other_link.prefixed_id)
      end

      it 'excludes links from incomplete orders' do
        pending_order = create(:order_with_line_items, store: store, customer: user)
        pending_item = pending_order.line_items.first
        pending_link = create(:digital_link,
                              digital_asset: create(:digital_asset, variant: pending_item.variant),
                              line_item: pending_item)

        get :index

        expect(json_response['data'].map { |l| l['id'] }).not_to include(pending_link.prefixed_id)
      end
    end

    context 'when not signed in' do
      it 'is unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
