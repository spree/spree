require 'spec_helper'

RSpec.describe Spree::Payments::HandleWebhookJob, type: :job do
  let(:store) { @default_store }
  let(:order) { create(:order_with_line_items, store: store) }
  let(:payment_method) { create(:bogus_payment_method) }
  let(:payment_session) { create(:bogus_payment_session, order: order, payment_method: payment_method, amount: order.total) }

  before do
    order.shipments.each { |s| s.update_column(:state, 'ready') }
  end

  describe '#perform' do
    it 'calls the HandleWebhook service with correct arguments' do
      handler = instance_double(Spree::Payments::HandleWebhook)
      allow(Spree::Payments::HandleWebhook).to receive(:new).and_return(handler)
      expect(handler).to receive(:call).with(
        payment_method: payment_method,
        action: :captured,
        payment_session: payment_session,
        metadata: { 'psp_reference' => 'PSP123' }
      )

      described_class.new.perform(
        payment_method_id: payment_method.id,
        action: 'captured',
        payment_session_id: payment_session.id,
        metadata: { 'psp_reference' => 'PSP123' }
      )
    end

    it 'passes empty metadata when enqueued without it' do
      handler = instance_double(Spree::Payments::HandleWebhook)
      allow(Spree::Payments::HandleWebhook).to receive(:new).and_return(handler)
      expect(handler).to receive(:call).with(hash_including(metadata: {}))

      described_class.new.perform(
        payment_method_id: payment_method.id,
        action: 'captured',
        payment_session_id: payment_session.id
      )
    end

    it 'converts action string to symbol' do
      handler = instance_double(Spree::Payments::HandleWebhook)
      allow(Spree::Payments::HandleWebhook).to receive(:new).and_return(handler)
      expect(handler).to receive(:call).with(
        hash_including(action: :authorized)
      )

      described_class.new.perform(
        payment_method_id: payment_method.id,
        action: 'authorized',
        payment_session_id: payment_session.id
      )
    end
    context 'when the payment method belongs to another store' do
      let(:other_store) { create(:store) }
      let(:payment_method) { create(:bogus_payment_method, store: other_store) }
      let(:order) { create(:order_with_line_items, store: other_store) }

      it 'handles the webhook in that store' do
        handled_in = nil
        allow_any_instance_of(Spree::Payments::HandleWebhook).to receive(:call) do
          handled_in = Spree::Current.store
          Spree::ServiceModule::Result.new(true, payment_session, nil)
        end

        described_class.perform_now(
          payment_method_id: payment_method.id,
          action: 'captured',
          payment_session_id: payment_session.id
        )

        expect(handled_in).to eq(other_store)
      end
    end
  end

  describe 'queue' do
    it 'uses the payment_webhooks queue' do
      expect(described_class.new.queue_name).to eq(Spree.queues.payment_webhooks.to_s)
    end
  end

  describe 'error handling' do
    it 'discards on ActiveRecord::RecordNotFound' do
      expect {
        described_class.perform_now(
          payment_method_id: 0,
          action: 'captured',
          payment_session_id: payment_session.id
        )
      }.not_to raise_error
    end

    it 'raises SettlementFailed when the workflow fails' do
      failed = Spree::ServiceModule::Result.new(false, payment_session, 'Stripe timeout')
      allow_any_instance_of(Spree::Payments::HandleWebhook).to receive(:call).and_return(failed)

      expect {
        described_class.new.perform(
          payment_method_id: payment_method.id,
          action: 'captured',
          payment_session_id: payment_session.id
        )
      }.to raise_error(described_class::SettlementFailed, /Stripe timeout/)
    end

    it 're-enqueues the job when the workflow fails' do
      failed = Spree::ServiceModule::Result.new(false, payment_session, 'Stripe timeout')
      allow_any_instance_of(Spree::Payments::HandleWebhook).to receive(:call).and_return(failed)

      expect {
        described_class.perform_now(
          payment_method_id: payment_method.id,
          action: 'captured',
          payment_session_id: payment_session.id
        )
      }.to have_enqueued_job(described_class)
    end

    # A cart a gateway took money for is fenced, so a requirement it fails
    # at completion stays failed: retrying only repeats it (SANDBOX-V2-1Y).
    context 'when the cart cannot complete for a reason a retry cannot change' do
      before do
        allow_any_instance_of(Spree::Payments::HandleWebhook).to receive(:call).and_return(failed)
        allow(Rails.error).to receive(:report)
      end

      def perform_job
        described_class.perform_now(
          payment_method_id: payment_method.id,
          action: 'captured',
          payment_session_id: payment_session.id
        )
      end

      %w[validation_failed coupon_code_unavailable tax_calculation_refused].each do |code|
        context "with #{code}" do
          let(:failed) do
            Spree::ServiceModule::Result.new(
              false, order, Spree::ServiceModule::ResultError.new({ code: code, message: 'cannot complete' })
            )
          end

          it 'does not retry' do
            expect { perform_job }.not_to have_enqueued_job(described_class)
          end

          it 'reports it once as an unhandled error naming the session and the reason' do
            perform_job

            expect(Rails.error).to have_received(:report).once.with(
              an_instance_of(described_class::CompletionBlocked),
              hash_including(
                handled: false,
                severity: :error,
                source: 'spree.payments.webhook',
                context: hash_including(
                  payment_session_id: payment_session.id,
                  payment_session_external_id: payment_session.external_id,
                  code: code
                )
              )
            )
          end
        end
      end

      context 'with an unmet checkout requirement' do
        let(:requirements) { [{ step: 'cart', field: 'line_items', code: 'line_items_required', message: 'Add an item' }] }
        let(:failed) do
          Spree::ServiceModule::Result.new(
            false, order, Spree::ServiceModule::ResultError.new({ code: 'validation_failed', errors: requirements })
          )
        end

        it 'reports which requirements the cart failed' do
          perform_job

          expect(Rails.error).to have_received(:report).with(
            anything, hash_including(context: hash_including(errors: requirements))
          )
        end
      end
    end

    %w[completion_in_progress payment_failed tax_provider_unavailable].each do |code|
      it "keeps retrying a #{code} failure, which a later attempt can clear" do
        failed = Spree::ServiceModule::Result.new(
          false, order, Spree::ServiceModule::ResultError.new({ code: code, message: 'try again' })
        )
        allow_any_instance_of(Spree::Payments::HandleWebhook).to receive(:call).and_return(failed)

        expect {
          described_class.perform_now(
            payment_method_id: payment_method.id,
            action: 'captured',
            payment_session_id: payment_session.id
          )
        }.to have_enqueued_job(described_class)
      end
    end

    it 'retries on ActiveRecord::Deadlocked' do
      expect(described_class.rescue_handlers).to include(
        have_attributes(first: 'ActiveRecord::Deadlocked')
      )
    end

    it 'retries on ActiveRecord::LockWaitTimeout' do
      expect(described_class.rescue_handlers).to include(
        have_attributes(first: 'ActiveRecord::LockWaitTimeout')
      )
    end
  end

  describe 'enqueuing' do
    it 'can be enqueued with perform_later' do
      expect {
        described_class.perform_later(
          payment_method_id: payment_method.id,
          action: 'captured',
          payment_session_id: payment_session.id
        )
      }.to have_enqueued_job(described_class)
    end
  end
end
