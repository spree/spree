require 'spec_helper'

RSpec.describe Spree::PaymentSessions::Complete do
  let(:store) { @default_store }
  let(:order) { create(:order, store: store, total: 50) }
  let(:payment_method) { create(:bogus_payment_method, store: store) }
  let(:payment_session) { create(:bogus_payment_session, order: order, payment_method: payment_method, amount: 50) }

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  it 'completes the session through the gateway' do
    result = described_class.call(payment_session: payment_session)

    expect(result).to be_success
    expect(result.value.status).to eq('completed')
  end

  it 'passes the client params through to the gateway' do
    expect(payment_method).to receive(:complete_payment_session).
      with(payment_session: payment_session, params: { 'session_result' => 'ok' })
    allow(payment_session).to receive(:payment_method).and_return(payment_method)

    described_class.call(payment_session: payment_session, params: { 'session_result' => 'ok' })
  end

  it 'is an idempotent success on an already-completed session' do
    payment_session.update_column(:status, 'completed')
    expect_any_instance_of(Spree::PaymentMethod).not_to receive(:complete_payment_session)

    result = described_class.call(payment_session: payment_session)

    expect(result).to be_success
  end

  it 'surfaces a gateway error as a failure result' do
    allow(payment_session).to receive(:payment_method).and_return(payment_method)
    allow(payment_method).to receive(:complete_payment_session).
      and_raise(Spree::Core::GatewayError, 'verification failed')

    result = described_class.call(payment_session: payment_session)

    expect(result).to be_failure
    expect(result.error.value).to eq('verification failed')
  end

  describe 'hooks' do
    it 'lets a validate handler veto settlement before the gateway is called' do
      expect_any_instance_of(Spree::PaymentMethod).not_to receive(:complete_payment_session)
      Spree.hooks.register('payment_sessions.complete.validate') { |flow| flow.reject!('on fraud hold') }

      result = described_class.call(payment_session: payment_session)

      expect(result).to be_failure
      expect(result.error.value).to eq('on fraud hold')
      expect(payment_session.reload.status).to eq('pending')
    end

    it 'runs after_complete with the settled session' do
      seen = nil
      Spree.hooks.register('payment_sessions.complete.after_complete') { |flow| seen = flow.payment_session.status }

      described_class.call(payment_session: payment_session)

      expect(seen).to eq('completed')
    end
  end
end
