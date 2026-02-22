require 'spec_helper'

RSpec.describe Spree::Admin::Orders::OrderPromotionsController do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:order) { create(:order_with_line_items, store: store) }

  describe '#new' do
    subject { get :new, params: { order_id: order.to_param } }

    it 'returns a success response' do
      subject
      expect(response).to be_successful
      expect(response).to render_template(:new)
    end
  end

  describe '#create' do
    subject { post :create, params: { order_id: order.to_param, coupon_code: coupon_code }, format: :turbo_stream }

    context 'with valid coupon code' do
      let(:promotion) { create(:promotion, :with_order_adjustment, code: 'TESTCODE', stores: [store]) }
      let(:coupon_code) { promotion.code }

      it 'applies the promotion' do
        expect { subject }.to change { order.order_promotions.count }.by(1)
      end

      it 'sets success flash message' do
        subject
        expect(flash[:success]).to be_present
      end

      it 'responds with turbo_stream' do
        subject
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end

      it 'sets @handler instance variable' do
        subject
        expect(assigns(:handler)).to be_a(Spree::PromotionHandler::Coupon)
        expect(assigns(:handler)).to be_successful
      end
    end

    context 'with invalid coupon code' do
      let(:coupon_code) { 'INVALID' }

      it 'does not create order promotion' do
        expect { subject }.not_to change { order.order_promotions.count }
      end

      it 'sets error flash message' do
        subject
        expect(flash[:error]).to be_present
      end

      it 'responds with turbo_stream' do
        subject
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end

    context 'with expired promotion' do
      let(:promotion) { create(:promotion, :with_order_adjustment, code: 'EXPIRED', stores: [store], starts_at: 3.days.ago, expires_at: 1.day.ago) }
      let(:coupon_code) { promotion.code }

      it 'sets error flash message' do
        subject
        expect(flash[:error]).to be_present
      end
    end
  end

  describe '#destroy' do
    subject { delete :destroy, params: { order_id: order.to_param, id: order_promotion.id }, format: :turbo_stream }

    context 'with valid applied promotion' do
      let(:promotion) { create(:promotion, :with_order_adjustment, code: 'REMOVE', stores: [store]) }
      let(:order_promotion) { order.order_promotions.find_by(promotion: promotion) }

      before do
        order.coupon_code = promotion.code
        Spree::PromotionHandler::Coupon.new(order).apply
        order.reload
      end

      it 'removes the promotion' do
        expect { subject }.to change { order.order_promotions.count }.by(-1)
      end

      it 'sets success flash message' do
        subject
        expect(flash[:success]).to be_present
      end

      it 'responds with turbo_stream' do
        subject
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end

      it 'sets @handler instance variable' do
        subject
        expect(assigns(:handler)).to be_a(Spree::PromotionHandler::Coupon)
        expect(assigns(:handler)).to be_successful
      end
    end
  end
end
