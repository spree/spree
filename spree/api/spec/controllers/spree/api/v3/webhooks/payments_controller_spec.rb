require 'spec_helper'

RSpec.describe Spree::Api::V3::Webhooks::PaymentsController, type: :controller do
  render_views

  let(:store) { @default_store }
  let(:payment_method) { create(:bogus_payment_method, stores: [store]) }

  describe 'POST #create' do
    context 'when webhook event is unsupported' do
      before do
        allow_any_instance_of(Spree::PaymentMethod).to receive(:parse_webhook_event).and_return(nil)
      end

      it 'returns ok without processing' do
        post :create, params: { payment_method_id: payment_method.prefixed_id }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when signature verification fails' do
      before do
        allow_any_instance_of(Spree::PaymentMethod).to receive(:parse_webhook_event)
          .and_raise(Spree::PaymentMethod::WebhookSignatureError)
      end

      it 'returns unauthorized' do
        post :create, params: { payment_method_id: payment_method.prefixed_id }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when payment method is not found' do
      it 'returns not found' do
        post :create, params: { payment_method_id: 'pm_nonexistent' }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow_any_instance_of(Spree::PaymentMethod).to receive(:parse_webhook_event)
          .and_raise(StandardError, 'unexpected')
      end

      it 'returns ok to prevent gateway retries' do
        expect(Rails.error).to receive(:report).with(kind_of(StandardError), hash_including(source: 'spree.webhooks.payments'))

        post :create, params: { payment_method_id: payment_method.prefixed_id }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when webhook is processed successfully' do
      let(:order) { create(:order_with_line_items, store: store) }
      let(:payment_session) { create(:bogus_payment_session, order: order, payment_method: payment_method) }

      before do
        allow_any_instance_of(Spree::PaymentMethod).to receive(:parse_webhook_event).and_return(
          { action: :captured, payment_session: payment_session, metadata: {} }
        )
      end

      it 'returns ok' do
        post :create, params: { payment_method_id: payment_method.prefixed_id }

        expect(response).to have_http_status(:ok)
      end

      it 'enqueues HandleWebhookJob' do
        expect {
          post :create, params: { payment_method_id: payment_method.prefixed_id }
        }.to have_enqueued_job(Spree::Payments::HandleWebhookJob).with(
          payment_method_id: payment_method.id,
          action: 'captured',
          payment_session_id: payment_session.id
        )
      end
    end
  end
end
