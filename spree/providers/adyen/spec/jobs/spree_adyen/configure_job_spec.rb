require 'spec_helper'

RSpec.describe SpreeAdyen::ConfigureJob, type: :job do
  let(:gateway) { create(:adyen_gateway) }

  it 'configures the payment method' do
    expect(SpreeAdyen::Configure).to receive(:call).with(gateway)

    described_class.perform_now(gateway.id)
  end

  it 'skips a payment method that is not Adyen' do
    expect(SpreeAdyen::Configure).not_to receive(:call)

    described_class.perform_now(create(:credit_card_payment_method).id)
  end

  # PayPal's webhook job runs on Spree's default queue, through its own
  # overridable queue setting; this job does the same.
  it "runs on the gem's queue, Spree's default unless set" do
    expect(SpreeAdyen.queue).to eq(Spree.queues.default)

    SpreeAdyen.queue = :adyen
    expect(described_class.new.queue_name).to eq('adyen')
  ensure
    SpreeAdyen.queue = nil
  end
end
