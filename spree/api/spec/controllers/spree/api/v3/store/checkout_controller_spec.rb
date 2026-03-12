require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::CheckoutController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:user) { create(:user_with_addresses) }
  let!(:order) { create(:order_with_line_items, store: store, user: user) }
  let(:country) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US') }
  let!(:us_state) { country.states.find_by(abbr: 'NY') || create(:state, country: country, abbr: 'NY', name: 'New York') }
  let!(:zone) { create(:zone, zone_members: [Spree::ZoneMember.new(zoneable: country)]) }
  let!(:shipping_method) { create(:shipping_method, zones: [zone]) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'PATCH #update' do
    it 'accepts ship_address_id to use an existing address' do
      order.update!(email: 'customer@example.com')
      existing_address = user.addresses.first || create(:address, user: user, country: country, state: us_state)

      patch :update, params: { ship_address_id: existing_address.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(order.reload.ship_address_id).to eq(existing_address.id)
    end

    it 'auto-advances to payment after address submission' do
      order.update!(email: 'customer@example.com')
      order.next # cart -> address
      order.reload
      expect(order.state).to eq('address')

      patch :update, params: {
        ship_address: {
          firstname: 'John', lastname: 'Doe',
          address1: '123 Main St', city: 'New York',
          zipcode: '10001', country_iso: 'US', state_abbr: 'NY',
          phone: '555-1234'
        }
      }

      expect(response).to have_http_status(:ok)
      expect(json_response['current_step']).to eq('payment')
    end
  end
end
