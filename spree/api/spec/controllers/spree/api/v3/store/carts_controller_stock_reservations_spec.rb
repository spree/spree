require 'spec_helper'

# Verifies Store API controllers wire reservation services at the right
# moments. Service-level behaviour is covered in
# spree/core/spec/services/spree/stock_reservations/.
RSpec.describe Spree::Api::V3::Store::CartsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:variant) { create(:variant) }
  let!(:stock_item) do
    si = variant.stock_items.first
    si.update!(backorderable: false)
    si.set_count_on_hand(20)
    si
  end

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    Spree::Config[:stock_reservations_enabled] = true
  end

  describe 'DELETE #destroy' do
    let(:cart) { create(:order, store: store) }
    let!(:line_item) { create(:line_item, order: cart, variant: variant, quantity: 2) }
    let!(:reservation) do
      create(
        :stock_reservation,
        stock_item: stock_item,
        line_item: line_item,
        order: cart,
        quantity: 2,
        expires_at: 5.minutes.from_now
      )
    end

    before { request.headers['x-spree-token'] = cart.token }

    it 'releases stock reservations belonging to the destroyed cart' do
      expect { delete :destroy, params: { id: cart.prefixed_id } }
        .to change { Spree::StockReservation.where(order_id: cart.id).count }.from(1).to(0)
    end
  end

  describe 'PATCH #update' do
    let(:cart) { create(:order, store: store, state: 'cart') }
    let!(:line_item) { create(:line_item, order: cart, variant: variant, quantity: 2) }

    before { request.headers['x-spree-token'] = cart.token }

    let(:address_attrs) do
      {
        first_name: 'Buyer', last_name: 'McGee',
        address1: '1 Test St', city: 'NYC',
        postal_code: '10001', phone: '555-0100',
        country_iso: 'US', state_name: 'New York'
      }
    end

    it 'creates a stock reservation when the cart leaves the cart state' do
      expect {
        patch :update, params: {
          id: cart.prefixed_id,
          email: 'buyer@example.com',
          shipping_address: address_attrs,
          billing_address: address_attrs
        }
      }.to change { Spree::StockReservation.where(order_id: cart.id).count }.by_at_least(1)
    end

    context 'when stock_reservations_enabled is false' do
      before { Spree::Config[:stock_reservations_enabled] = false }
      after { Spree::Config[:stock_reservations_enabled] = true }

      it 'does not create reservations' do
        expect {
          patch :update, params: {
            id: cart.prefixed_id,
            email: 'buyer@example.com',
            shipping_address: address_attrs,
            billing_address: address_attrs
          }
        }.not_to change { Spree::StockReservation.where(order_id: cart.id).count }
      end
    end
  end
end
