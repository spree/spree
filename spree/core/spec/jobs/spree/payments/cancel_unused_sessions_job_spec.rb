require 'spec_helper'
require 'active_job/continuation/test_helper'

RSpec.describe Spree::Payments::CancelUnusedSessionsJob, type: :job do
  let(:store) { @default_store }
  let(:order) { create(:order_ready_to_ship, store: store) }
  let!(:unused_session) { create(:bogus_payment_session, order: order) }

  it 'cancels the sessions left pending with nothing paid through them' do
    described_class.perform_now(order.id)

    expect(unused_session.reload.status).to eq('canceled')
  end

  it 'asks the provider to cancel a failed session nothing was paid through' do
    unused_session.update_columns(status: 'failed')

    described_class.perform_now(order.id)

    expect(unused_session.reload.status).to eq('canceled')
  end

  it 'leaves a session that settled a payment alone' do
    order.payments.first.update_columns(response_code: unused_session.external_id)

    described_class.perform_now(order.id)

    expect(unused_session.reload.status).to eq('pending')
  end

  it 'reports a refusal and carries on with the other sessions' do
    other_session = create(:bogus_payment_session, order: order, payment_method: unused_session.payment_method)
    allow_any_instance_of(Spree::PaymentSessions::Bogus).to receive(:cancel).and_wrap_original do |method, *arguments|
      raise Spree::Core::GatewayError, 'already paid' if method.receiver.id == unused_session.id

      method.call(*arguments)
    end
    allow(Rails.error).to receive(:report)

    described_class.perform_now(order.id)

    expect(unused_session.reload.status).to eq('pending')
    expect(other_session.reload.status).to eq('canceled')
    expect(Rails.error).to have_received(:report).
      with(an_instance_of(Spree::Core::GatewayError), hash_including(source: 'spree.payments.cancel_unused_sessions'))
  end

  it 'does nothing for an order that no longer exists' do
    expect { described_class.perform_now('nonexistent') }.not_to raise_error
  end

  describe 'interruption and resume' do
    include ActiveJob::Continuation::TestHelper

    around do |example|
      original = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      example.run
    ensure
      ActiveJob::Base.queue_adapter = original
    end

    it 'asks again about a session the provider could not be reached about' do
      other_session = create(:bogus_payment_session, order: order, payment_method: unused_session.payment_method)
      second_session = [unused_session, other_session].max_by(&:id)
      attempts = 0
      allow_any_instance_of(Spree::PaymentSessions::Bogus).to receive(:cancel).and_wrap_original do |method, *arguments|
        if method.receiver.id == second_session.id
          attempts += 1
          raise Timeout::Error, 'timed out' if attempts == 1
        end

        method.call(*arguments)
      end

      described_class.perform_later(order.id)
      perform_enqueued_jobs

      expect(second_session.reload.status).to eq('pending')

      perform_enqueued_jobs

      expect(attempts).to eq(2)
      expect(second_session.reload.status).to eq('canceled')
    end

    it 'leaves the first session pending when the provider cannot be reached' do
      allow_any_instance_of(Spree::PaymentSessions::Bogus).to receive(:cancel).
        and_raise(Spree::Core::AmbiguousGatewayError, 'connection timed out')
      allow(Rails.error).to receive(:report)

      described_class.perform_later(order.id)

      expect { perform_enqueued_jobs }.to raise_error(Spree::Core::AmbiguousGatewayError)
      expect(unused_session.reload.status).to eq('pending')
      expect(Rails.error).not_to have_received(:report).
        with(anything, hash_including(source: 'spree.payments.cancel_unused_sessions'))
    end

    it 'does not ask the provider again about a session it already refused' do
      other_session = create(:bogus_payment_session, order: order, payment_method: unused_session.payment_method)
      first_session, second_session = [unused_session, other_session].sort_by(&:id)
      refusals = 0
      allow_any_instance_of(Spree::PaymentSessions::Bogus).to receive(:cancel).and_wrap_original do |method, *arguments|
        next method.call(*arguments) unless method.receiver.id == first_session.id

        refusals += 1
        raise Spree::Core::GatewayError, 'already paid'
      end
      allow(Rails.error).to receive(:report)

      described_class.perform_later(order.id)

      interrupt_job_during_step(described_class, :cancel_sessions, cursor: first_session.id) do
        perform_enqueued_jobs
      end
      perform_enqueued_jobs

      expect(refusals).to eq(1)
      expect(second_session.reload.status).to eq('canceled')
    end
  end
end
