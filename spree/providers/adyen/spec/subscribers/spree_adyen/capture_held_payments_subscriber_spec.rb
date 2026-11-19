require 'spec_helper'

RSpec.describe SpreeAdyen::CaptureHeldPaymentsSubscriber do
  subject(:handle) { described_class.new.handle(event) }

  let(:store) { @default_store }
  let(:gateway) { create(:adyen_gateway, :configured, store: store) }
  let(:payment) { adyen_session_payment(gateway: gateway) }
  let(:event) { instance_double(Spree::Event, payload: { 'id' => payment.order.prefixed_id }) }
  let(:capture_workflow) { class_double(Spree::Payments::Capture, call: Spree::ServiceModule::Result.new(true, nil, nil)) }

  before { allow(Spree).to receive(:payment_capture_workflow).and_return(capture_workflow) }

  def held_by_adyen(variant)
    payment.update!(metadata: payment.metadata.merge('adyen_variant' => variant))
  end

  it 'captures a payment Adyen holds for a capture request when the method captures at checkout' do
    held_by_adyen('klarna_paylater')

    handle

    expect(capture_workflow).to have_received(:call).with(payment: payment)
  end

  it 'reports a capture Adyen refused, so someone captures it again' do
    held_by_adyen('klarna')
    refused = Spree::ServiceModule::Result.new(false, payment, Spree::ServiceModule::ResultError.new('Refused'))
    allow(capture_workflow).to receive(:call).and_return(refused)
    allow(Rails.error).to receive(:report)

    handle

    expect(Rails.error).to have_received(:report).with(
      an_instance_of(Spree::Core::GatewayError).and(having_attributes(message: 'Refused')),
      handled: true, context: { payment_id: payment.prefixed_id, order_id: payment.order.prefixed_id }
    )
  end

  it 'leaves a card, which Adyen captured itself' do
    held_by_adyen('visa')

    handle

    expect(capture_workflow).not_to have_received(:call)
  end

  it 'leaves a held method when the method captures later' do
    gateway.update!(capture_method: 'manual')
    held_by_adyen('klarna')

    handle

    expect(capture_workflow).not_to have_received(:call)
  end

  it 'leaves a payment that is no longer authorized' do
    held_by_adyen('klarna')
    payment.update_columns(status: 'requested')

    handle

    expect(capture_workflow).not_to have_received(:call)
  end

  it 'does nothing for an order that no longer exists' do
    missing = instance_double(Spree::Event, payload: { 'id' => 'or_missing' })

    expect { described_class.new.handle(missing) }.not_to raise_error
  end
end
