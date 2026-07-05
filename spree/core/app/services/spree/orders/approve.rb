module Spree
  module Orders
    class Approve
      prepend Spree::ServiceModule::Base

      # Approves an order and records a Spree::OrderApproval history record.
      #
      # The legacy keyword `approver:` remains valid; new keywords (`level:`, `note:`)
      # are additive and stored on the approval record.
      #
      # @param order [Spree::Order]
      # @param approver [Object, nil] the user/admin who approved
      # @param level [String, nil] approval level (used by 6.0 multi-level B2B flow)
      # @param note [String, nil] staff-facing note
      # @return [Spree::ServiceModule::Result]
      def call(order:, approver: nil, level: nil, note: nil)
        decided_at = Time.current

        order.transaction do
          order.approvals.create!(
            status: 'approved',
            level: level,
            note: note,
            approver: approver,
            decided_at: decided_at,
            created_at: decided_at
          )

          changes = { considered_risky: false, approved_at: decided_at }
          changes[:approver_id] = approver.id if approver.present?
          order.update_columns(changes)
        end

        order.publish_event('order.approved')
        success(order.reload)
      rescue ActiveRecord::RecordInvalid, StateMachines::InvalidTransition
        failure(order)
      end
    end
  end
end
