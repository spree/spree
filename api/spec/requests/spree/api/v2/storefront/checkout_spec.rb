require 'spec_helper'

describe 'API V2 Storefront Checkout Spec', type: :request do
  let!(:user)  { create(:user) }
  let!(:token) { Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: nil) }
  let!(:order) { create(:order_with_line_items, user: user) }

  describe 'checkout#next' do
    context 'without line items' do
      before do
        order.line_items.destroy_all
        headers = { 'Authorization' => "Bearer #{token.token}" }
        patch '/api/v2/storefront/checkout/next', headers: headers
      end

      it 'cannot transition to address without a line item' do
        expect(response.status).to eq(422)
        expect(json_response['base']).to include(Spree.t(:there_are_no_items_for_this_order))
      end
    end

    context 'with line_items and email' do
      before do
        headers = { 'Authorization' => "Bearer #{token.token}" }
        patch '/api/v2/storefront/checkout/next', headers: headers
      end

      it 'can transition an order to the next state' do
        expect(response.status).to       eq(200)
        expect(json_response['data']).to have_attribute(:state).with_value('address')
      end
    end

    context 'without payment info' do
      before do
        order.update_column(:state, 'payment')
        headers = { 'Authorization' => "Bearer #{token.token}" }
        patch '/api/v2/storefront/checkout/next', headers: headers
      end

      it 'doesnt advance payment state if order has no payment' do
        expect(response.status).to       eq(422)
        expect(json_response['base']).to include(Spree.t(:no_payment_found))
      end
    end
  end

  describe 'checkout#advance' do
    context 'with payment data' do
      before do
        create(:payment, amount: order.total, order: order)
        headers = { 'Authorization' => "Bearer #{token.token}" }
        patch '/api/v2/storefront/checkout/advance', headers: headers
      end

      it 'advances an order till complete or confirm step' do
        expect(response.status).to       eq(200)
        expect(json_response['data']).to have_attribute(:state).with_value('confirm')
      end
    end

    context 'without payment data' do
      before do
        headers = { 'Authorization' => "Bearer #{token.token}" }
        patch '/api/v2/storefront/checkout/advance', headers: headers
      end

      it 'doesnt advance payment state if order has no payment' do
        expect(response.status).to       eq(422)
        expect(json_response['base']).to include(Spree.t(:no_payment_found))
      end
    end
  end

  describe 'checkout#complete' do
    context 'with payment data' do
      before do
        create(:payment, amount: order.total, order: order)
        headers = { 'Authorization' => "Bearer #{token.token}" }
        patch '/api/v2/storefront/checkout/complete', headers: headers
      end

      it 'advances an order till complete step' do
        expect(response.status).to       eq(200)
        expect(json_response['data']).to have_attribute(:state).with_value('complete')
      end
    end

    context 'without payment data' do
      before do
        headers = { 'Authorization' => "Bearer #{token.token}" }
        patch '/api/v2/storefront/checkout/complete', headers: headers
      end

      it 'returns errors' do
        expect(response.status).to       eq(422)
        expect(json_response['base']).to include(Spree.t(:no_payment_found))
      end
    end
  end
end
