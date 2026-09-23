require 'spec_helper'

RSpec.describe Spree::Api::V3::Webhooks::PayoutsController, type: :controller do
  render_views

  let(:store) { @default_store }
  let(:other_store) { create(:store) }
  let(:payment_method) { create(:bogus_payment_method, store: other_store) }
  let(:handled_in) { [] }

  # Providers call back without an API key or store header, so the request
  # host names the default store — the payment method decides the store.
  before do
    request.host = store.url
    allow_any_instance_of(Spree::Gateway::Bogus).to receive(:handle_payout_webhook) { handled_in << Spree::Current.store }
  end

  describe 'POST #create' do
    it "handles the event in the payment method's store" do
      post :create, params: { payment_method_id: payment_method.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(handled_in).to eq([other_store])
    end

    it 'returns unauthorized when the signature does not verify' do
      allow_any_instance_of(Spree::Gateway::Bogus).to receive(:handle_payout_webhook)
        .and_raise(Spree::PaymentMethod::WebhookSignatureError)

      post :create, params: { payment_method_id: payment_method.prefixed_id }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns not found for an unknown payment method' do
      post :create, params: { payment_method_id: 'pm_nonexistent' }

      expect(response).to have_http_status(:not_found)
      expect(handled_in).to be_empty
    end

    it 'returns not found for a payment method without payout events' do
      check_payment_method = create(:check_payment_method, store: other_store)

      post :create, params: { payment_method_id: check_payment_method.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns a server error when handling fails, so the provider retries' do
      allow_any_instance_of(Spree::Gateway::Bogus).to receive(:handle_payout_webhook).and_raise(StandardError, 'unexpected')
      expect(Rails.error).to receive(:report).with(kind_of(StandardError), hash_including(source: 'spree.webhooks.payouts'))

      post :create, params: { payment_method_id: payment_method.prefixed_id }

      expect(response).to have_http_status(:internal_server_error)
    end
  end
end
