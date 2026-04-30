require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::PaymentsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order_with_payment) { create(:order_ready_to_ship, store: store) }
  let!(:payment) { order_with_payment.payments.first }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns payments for the order' do
      get :index, params: { order_id: order_with_payment.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].length).to be >= 1
    end
  end

  describe 'GET #show' do
    it 'returns the payment' do
      get :show, params: { order_id: order_with_payment.prefixed_id, id: payment.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(payment.prefixed_id)
      expect(json_response['status']).to be_present
    end

    it 'returns 404 for unknown payment id' do
      get :show, params: { order_id: order_with_payment.prefixed_id, id: 'pay_unknown' }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    let(:order) { create(:completed_order_with_totals, store: store) }
    let(:payment_method) { create(:check_payment_method, stores: [store]) }

    it 'creates a payment' do
      post :create, params: {
        order_id: order.prefixed_id,
        payment_method_id: payment_method.prefixed_id,
        amount: order.total
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to be_present
    end

    it 'returns 404 for unknown payment_method prefixed id' do
      post :create, params: {
        order_id: order.prefixed_id,
        payment_method_id: 'pm_unknown',
        amount: order.total
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    context 'when payment_method does not require a source' do
      it 'ignores source_id silently' do
        post :create, params: {
          order_id: order.prefixed_id,
          payment_method_id: payment_method.prefixed_id,
          source_id: 'card_doesnt_matter',
          amount: order.total
        }, as: :json

        expect(response).to have_http_status(:created)
        payment = order.payments.find_by_prefix_id(json_response['id'])
        expect(payment.source).to be_nil
      end
    end

    context 'off-session charge against a saved credit card (source_id)' do
      let(:customer) { create(:user) }
      let(:order) { create(:completed_order_with_totals, store: store, user: customer) }
      let(:credit_card_method) { create(:credit_card_payment_method, stores: [store]) }
      let(:saved_card) { create(:credit_card, user: customer, payment_method: credit_card_method) }

      it 'attaches the saved card as the payment source' do
        post :create, params: {
          order_id: order.prefixed_id,
          payment_method_id: credit_card_method.prefixed_id,
          source_id: saved_card.prefixed_id,
          amount: order.total
        }, as: :json

        expect(response).to have_http_status(:created)
        payment = order.payments.find_by_prefix_id(json_response['id'])
        expect(payment.source).to eq(saved_card)
        expect(payment.payment_method).to eq(credit_card_method)
      end

      context 'when source belongs to a different customer' do
        let(:other_customer) { create(:user) }
        let(:other_card) { create(:credit_card, user: other_customer, payment_method: credit_card_method) }

        it 'returns 404 to prevent cross-customer use' do
          post :create, params: {
            order_id: order.prefixed_id,
            payment_method_id: credit_card_method.prefixed_id,
            source_id: other_card.prefixed_id,
            amount: order.total
          }, as: :json

          expect(response).to have_http_status(:not_found)
          expect(order.reload.payments.count).to eq(0)
        end
      end

      context 'with invalid source prefix id' do
        it 'returns 404' do
          post :create, params: {
            order_id: order.prefixed_id,
            payment_method_id: credit_card_method.prefixed_id,
            source_id: 'card_doesnt_exist',
            amount: order.total
          }, as: :json

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when amount is missing' do
      it 'defaults to order total after store credit' do
        post :create, params: {
          order_id: order.prefixed_id,
          payment_method_id: payment_method.prefixed_id
        }, as: :json

        expect(response).to have_http_status(:created)
        payment = order.payments.find_by_prefix_id(json_response['id'])
        expect(payment.amount).to eq(order.order_total_after_store_credit)
      end
    end
  end

  describe 'PATCH #capture' do
    before do
      payment.update_column(:state, 'pending') if payment.state != 'pending'
    end

    it 'captures the payment' do
      patch :capture, params: {
        order_id: order_with_payment.prefixed_id,
        id: payment.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('completed')
      expect(payment.reload.state).to eq('completed')
    end

    context 'when payment is already completed' do
      before { payment.update_column(:state, 'completed') }

      it 'is a no-op (state machine treats this as success)' do
        patch :capture, params: {
          order_id: order_with_payment.prefixed_id,
          id: payment.prefixed_id
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(payment.reload.state).to eq('completed')
      end
    end

    context 'when the gateway returns a failure' do
      before do
        # Bogus gateway forces a failure when the authorization doesn't start with `BGS-`.
        payment.update_column(:response_code, 'INVALID-AUTH')
      end

      it 'returns 422 with the gateway error message' do
        patch :capture, params: {
          order_id: order_with_payment.prefixed_id,
          id: payment.prefixed_id
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['message']).to eq('Bogus Gateway: Forced failure')
        expect(payment.reload.state).to eq('failed')
      end
    end
  end

  describe 'PATCH #void' do
    it 'voids the payment' do
      patch :void, params: {
        order_id: order_with_payment.prefixed_id,
        id: payment.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('void')
      expect(payment.reload.state).to eq('void')
    end

    context 'when payment is already voided' do
      before { payment.update_column(:state, 'void') }

      it 'is a no-op (state machine treats this as success)' do
        patch :void, params: {
          order_id: order_with_payment.prefixed_id,
          id: payment.prefixed_id
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(payment.reload.state).to eq('void')
      end
    end

  end
end
