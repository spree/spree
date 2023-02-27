require 'spec_helper'

describe 'Platform API v2 Stock Items API' do
  include_context 'Platform API v2'

  let!(:stock_location_1) { create(:stock_location) }
  let!(:stock_location_2) { create(:stock_location) }
  let(:bearer_token) { { 'Authorization' => valid_authorization } }

  describe 'stock_items#index' do
    let!(:variant_1) { create(:variant) }
    let!(:variant_2) { create(:variant) }

    context 'filtering' do
      before { get "/api/v2/platform/stock_items?filter[stock_location_id_eq]=#{stock_location_1.id}", headers: bearer_token }

      it 'returns stock_items with matching stock location ids' do
        expect(json_response['data'].count).to eq 4
      end
    end
  end
end

