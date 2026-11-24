module Spree
  module Payments
    # Runs Spree::Payments::HandleModificationWebhook for an outcome the
    # webhook endpoint accepted: the provider got its 200 already and will not
    # send it again, so a failure is retried here.
    #
    # An outcome can name a record Spree has not written yet: it arrived
    # before the request that writes it finished, or that request's answer
    # never reached Spree and a retry of it writes the record later. The job
    # waits for the record as long as a retried request still gets the
    # provider's first answer.
    class HandleModificationWebhookJob < Spree::BaseJob
      queue_as Spree.queues.payment_webhooks

      retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
      retry_on ActiveRecord::LockWaitTimeout, wait: 5.seconds, attempts: 3
      discard_on ActiveRecord::RecordNotFound

      class OutcomeFailed < StandardError; end
      # The wait ended with no record: an action taken outside Spree, or a
      # request whose answer never reached Spree and that nobody retried.
      class RecordNeverWritten < StandardError; end

      retry_on OutcomeFailed, wait: :polynomially_longer, attempts: 5

      CAPTURE_ACTIONS = %w[capture_succeeded capture_failed].freeze
      # How long a retried request still gets the provider's first answer:
      # Adyen keeps an idempotency key for at least 7 days.
      RECORD_WAIT = 7.days
      # Longer than any gateway call takes with its own retries, so after it
      # no request for this outcome can still be running.
      ANSWER_WINDOW = 5.minutes

      # @param reference [String] the provider reference the outcome names its record by
      # @param received_at [String] when the endpoint accepted the outcome, ISO 8601
      # @param payment_id [Integer, nil] the payment a capture outcome's capture was asked for
      def perform(payment_method_id:, action:, reference:, received_at:, payment_id: nil, metadata: {})
        payment_method = Spree::PaymentMethod.find(payment_method_id)
        Spree::Current.store = payment_method.store
        received_at = Time.zone.parse(received_at)

        record = payment_method.modification_record(action.to_sym, reference) ||
                 unanswered_capture(payment_method, action, reference, payment_id, metadata, received_at)
        return wait_for_record(payment_method, action, reference, received_at) if record.nil?

        result = Spree.payments_handle_modification_webhook_workflow.call(
          payment_method: payment_method,
          action: action.to_sym,
          record: record,
          metadata: metadata
        )

        raise OutcomeFailed, "#{action} #{reference}: #{result.error}" if result&.failure?
      end

      private

      # A capture whose answer never reached Spree leaves its payment
      # processing, with no capture event waiting. Once no request can still be
      # running, the event is written as the request would have, so the
      # outcome settles it.
      def unanswered_capture(payment_method, action, reference, payment_id, metadata, received_at)
        return unless CAPTURE_ACTIONS.include?(action.to_s) && payment_id
        return if Time.current - received_at < ANSWER_WINDOW

        payment = Spree::Payment.where(payment_method_id: payment_method.id).find_by(id: payment_id)
        return if payment.nil?

        payment.with_lock do
          next unless payment.processing? && payment.capture_events.where(status: 'requested').none?

          amount = metadata['amount'].presence&.to_d || payment.amount
          payment.capture_events.create!(amount: amount, status: 'requested', transaction_id: reference)
        end
      end

      # Looks again quickly at first, when the record is most likely only
      # moments away, then every few hours.
      def wait_for_record(payment_method, action, reference, received_at)
        if Time.current - received_at < RECORD_WAIT
          retry_job(wait: [5.seconds * (4**(executions - 1).clamp(0, 8)), 6.hours].min)
        else
          Rails.error.report(
            RecordNeverWritten.new("#{action} names no record: #{reference}"),
            handled: true,
            context: { payment_method_id: payment_method.id, action: action, reference: reference },
            source: 'spree.payments.modification_webhook'
          )
        end
      end
    end
  end
end
