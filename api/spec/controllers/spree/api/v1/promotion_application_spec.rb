require 'spec_helper'

module Spree
  describe Api::V1::OrdersController, type: :controller do
    render_views

    before do
      stub_authentication!
    end

    context 'with an available promotion' do
      let!(:order) { create(:order_with_line_items, line_items_count: 1) }
      let!(:promotion) do
        promotion = Spree::Promotion.create(name: '10% off', code: '10off')
        calculator = Spree::Calculator::FlatPercentItemTotal.create(preferred_flat_percent: '10')
        action = Spree::Promotion::Actions::CreateItemAdjustments.create(calculator: calculator)
        promotion.actions << action
        promotion
      end

      it 'can apply a coupon code to the order' do
        expect(order.total).to eq(110.00)
        api_put :apply_coupon_code, id: order.to_param, coupon_code: '10off', order_token: order.token
        expect(response.status).to eq(200)
        expect(order.reload.total).to eq(109.00)
        expect(json_response['success']).to eq('The coupon code was successfully applied to your order.')
        expect(json_response['error']).to be_blank
        expect(json_response['successful']).to be true
        expect(json_response['status_code']).to eq('coupon_code_applied')
      end

      context 'with an expired promotion' do
        before do
          promotion.starts_at = 2.weeks.ago
          promotion.expires_at = 1.week.ago
          promotion.save
        end

        it 'fails to apply' do
          api_put :apply_coupon_code, id: order.to_param, coupon_code: '10off', order_token: order.token
          expect(response.status).to eq(422)
          expect(json_response['success']).to be_blank
          expect(json_response['error']).to eq('The coupon code is expired')
          expect(json_response['successful']).to be false
          expect(json_response['status_code']).to eq('coupon_code_expired')
        end
      end
    end
  end
end
