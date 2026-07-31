module Spree
  module Orders
    # Resumes a canceled order — the counterpart of {Spree::Orders::Cancel},
    # absorbing what Order#after_resume buried: the status flip and
    # fulfillment resumption commit atomically (with the after_resume hook
    # inside the transaction), then risk reassessment, status recomputation
    # and the order.resumed event.
    class Resume < Spree::Workflow
      hooks :after_resume

      # @param order [Spree::Order]
      def perform(order:)
        super

        step :ensure_resumable

        ApplicationRecord.transaction do
          step :mark_placed
          step :resume_fulfillments
          run_hooks :after_resume
        end

        order.consider_risk
        step :recompute_statuses, with: -> { Spree::Orders::RecomputeStatuses }
        order.publish_event('order.resumed')
        success(order.reload)
      rescue ActiveRecord::RecordInvalid, StateMachines::InvalidTransition
        failure(order)
      end

      private

      def ensure_resumable
        failure(order) unless order.canceled?
      end

      def mark_placed
        order.update_columns(status: 'placed')
      end

      def resume_fulfillments
        order.fulfillments.each(&:resume!)
      end
    end
  end
end
