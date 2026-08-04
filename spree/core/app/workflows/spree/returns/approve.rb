module Spree
  module Returns
    # Authorizes a requested return, optionally producing a prepaid return
    # label from the carrier.
    class Approve < Spree::Workflow
      hooks :validate, :after_approve

      # @param return_record [Spree::Return]
      # @param approver [Object, nil] the admin approving it
      # @param generate_label [Boolean] ask the carrier for a return label
      def perform(return_record:, approver: nil, generate_label: false)
        super

        step :ensure_approvable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_approved
        end

        # Carrier API — never inside the transaction above.
        external_step :request_return_label if generate_label

        run_hooks :after_approve
        return_record.publish_event('return.approved')
        success(return_record.reload)
      end

      private

      def ensure_approvable
        failure(return_record, :not_requested) unless return_record.requested?
      end

      def mark_approved
        return_record.update!(
          status: 'approved',
          approved_at: Time.current,
          created_by: return_record.created_by || approver
        )
      end

      # Label generation is best-effort: a carrier outage should not undo an
      # approval the merchant already granted. The failure is reported and
      # the return stays approved without a label.
      def request_return_label
        provider = Spree::Dependencies.respond_to?(:return_label_provider) ? Spree.return_label_provider : nil
        return if provider.nil?

        url = provider.call(return_record: return_record)
        return_record.update_columns(return_label_url: url) if url.present?
      rescue StandardError => error
        Rails.error.report(
          error,
          context: { return_id: return_record.id },
          source: 'spree.returns.label'
        )
      end
    end
  end
end
