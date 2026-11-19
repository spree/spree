module SpreeAdyen
  module MaintenanceTasks
    # Gives Adyen payments taken under the 5.x gem the 6.0 shape:
    #
    # - a payment from 5.x's legacy checkout, whose response code its webhook
    #   rewrote to the PSP reference, gets that reference in
    #   metadata['adyen_psp_reference'], where captures, cancels, refunds and
    #   the dashboard link read it. Its response code stays, since no session
    #   links to it;
    # - a payment-session payment, keyed on the session id with no PSP
    #   reference anywhere, cannot be recovered: Adyen has no lookup from a
    #   session id. It is counted and logged by id, to handle in Adyen;
    # - the capture and cancellation references 5.x kept in custom fields move
    #   to the capture event and the payment's metadata, and the values go;
    # - a payment left in 5.x's capture_pending or void_pending is marked done,
    #   since Adyen will not send its outcome again.
    class MigratePayments < Spree::MaintenanceTask
      CAPTURE_FIELD = 'adyen.capture_psp_reference'.freeze
      CANCELLATION_FIELD = 'adyen.cancellation_psp_reference'.freeze

      supports_dry_run

      def collection
        gateway_ids = Spree::PaymentMethod.unscoped.where(type: 'SpreeAdyen::Gateway').select(:id)
        Spree::Payment.unscoped.where(payment_method_id: gateway_ids).where.not(response_code: [nil, '']).order(:id)
      end

      # One transaction per payment, so a retry after a failure never finds a
      # capture event written without the status change that goes with it.
      def process(payment)
        payment.transaction do
          capture_reference = payment.get_custom_field(CAPTURE_FIELD)&.value.presence&.to_s
          changed = record_psp_reference(payment)
          changed |= move_custom_fields(payment)
          changed |= finish_pending_status(payment, capture_reference)
          tally(:unchanged) unless changed
        end
      end

      # The two custom field definitions belong to merchants' data, so they go
      # once no value is left.
      def after_complete
        return if dry_run?

        Spree::CustomFieldDefinition.where(namespace: 'adyen', key: %w[capture_psp_reference cancellation_psp_reference]).
          find_each { |definition| definition.destroy if definition.custom_fields.none? }
      end

      private

      def record_psp_reference(payment)
        return false if payment.metadata['adyen_psp_reference'].present?

        if session_payment?(payment)
          Rails.logger.warn("[spree_adyen] migrate_adyen_payments: payment #{payment.id} has no PSP reference; handle it in Adyen")
          tally(:unrecoverable)
          return true
        end
        if dry_run?
          tally(:would_convert)
          return true
        end

        payment.update_columns(metadata: payment.metadata.merge('adyen_psp_reference' => payment.response_code), updated_at: Time.current)
        tally(:converted)
        true
      end

      def session_payment?(payment)
        Spree::PaymentSession.unscoped.exists?(payment_method_id: payment.payment_method_id, external_id: payment.response_code)
      end

      def move_custom_fields(payment)
        capture_field = payment.get_custom_field(CAPTURE_FIELD)
        cancellation_field = payment.get_custom_field(CANCELLATION_FIELD)
        return false if capture_field.nil? && cancellation_field.nil?

        if dry_run?
          tally(:would_move_references)
          return true
        end

        if capture_field
          capture_event = payment.capture_events.where(transaction_id: nil).order(:id).last
          capture_event&.update_columns(transaction_id: capture_field.value.to_s, updated_at: Time.current)
          capture_field.destroy
        end
        if cancellation_field
          references = Array(payment.metadata['adyen_cancel_references']) | [cancellation_field.value.to_s]
          payment.update_columns(metadata: payment.metadata.merge('adyen_cancel_references' => references), updated_at: Time.current)
          cancellation_field.destroy
        end
        tally(:moved_references)
        true
      end

      # Adyen's acceptance is counted as done for these legacy rows only.
      def finish_pending_status(payment, capture_reference)
        status = payment.read_attribute(:status)
        return false unless status.in?(%w[capture_pending void_pending])

        Rails.logger.warn("[spree_adyen] migrate_adyen_payments: payment #{payment.id} was #{status}; marked done, check it in Adyen")
        if dry_run?
          tally(:would_mark_done)
          return true
        end

        if status == 'capture_pending'
          payment.capture_events.create!(amount: payment.amount, status: 'completed',
                                         transaction_id: capture_reference || payment.metadata['adyen_psp_reference'])
          payment.update_columns(status: 'completed', updated_at: Time.current)
        else
          payment.update_columns(status: 'void', updated_at: Time.current)
        end
        refresh_owner(payment)
        tally(:marked_done)
        true
      end

      # The column writes skip the payment events that keep the order's paid
      # total and payment status current, so they are refreshed here instead.
      def refresh_owner(payment)
        owner = payment.owner
        owner.refresh_payment_total! if owner.respond_to?(:refresh_payment_total!)
        owner.update_statuses! if owner.is_a?(Spree::Order)
      end
    end
  end
end
