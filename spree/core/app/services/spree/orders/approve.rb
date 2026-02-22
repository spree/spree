module Spree
  module Orders
    class Approve
      prepend Spree::ServiceModule::Base

      def call(order:, approver: nil)
        changes = { considered_risky: false, approved_at: Time.current }
        if approver.present?
          changes[:approver_id] = approver.id
        end
        order.update_columns(changes)

        order.publish_event('order.approved')
        success(order.reload)
      rescue ActiveRecord::Rollback, ActiveRecord::RecordInvalid, StateMachines::InvalidTransition
        failure(order)
      end
    end
  end
end
