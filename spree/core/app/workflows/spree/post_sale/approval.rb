module Spree
  module PostSale
    # Approval shared by returns, exchanges and claims. The including
    # workflow names the record it approves (`post_sale_record`) and the
    # status that record must be in (`approvable_status`).
    module Approval
      private

      def approve
        step :ensure_approvable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_approved
        end

        run_hooks :after_approve
        post_sale_record.publish_event("#{post_sale_record.event_prefix}.approved")
        success(post_sale_record.reload)
      end

      def ensure_approvable
        failure(post_sale_record, :"not_#{approvable_status}") unless post_sale_record.status == approvable_status
      end

      def mark_approved
        post_sale_record.update!(
          status: 'approved',
          approved_at: Time.current,
          created_by: post_sale_record.created_by || approver
        )
      end
    end
  end
end
