require 'spec_helper'

RSpec.describe SpreePaypalCheckout::RegisterWebhookJob do
  let(:gateway) { create(:paypal_checkout_gateway) }

  it 'registers the webhook of the payment method' do
    registered = []
    allow_any_instance_of(SpreePaypalCheckout::Gateway).to receive(:register_webhook) { |payment_method| registered << payment_method.id }

    described_class.perform_now(gateway.id)

    expect(registered).to eq([gateway.id])
  end

  it 'skips a payment method that no longer exists' do
    expect { described_class.perform_now(0) }.not_to raise_error
  end

  it 'skips a payment method of another kind' do
    other = create(:check_payment_method)

    expect { described_class.perform_now(other.id) }.not_to raise_error
  end

  it 'retries when PayPal cannot be reached' do
    allow_any_instance_of(SpreePaypalCheckout::Gateway).to receive(:register_webhook).and_raise(Net::OpenTimeout)

    expect { described_class.perform_now(gateway.id) }.to have_enqueued_job(described_class).with(gateway.id)
  end
end
