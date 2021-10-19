module Spree
  module Orders
    class Approve
      prepend Spree::ServiceModule::Base

      def call(order:, approver: nil)
        if approver.present?
          order.approved_by(approver)
        else
          order.approve!
        end
        success(order.reload)
      rescue ActiveRecord::Rollback, ActiveRecord::RecordInvalid, StateMachines::InvalidTransition
        failure(order)
      end
    end
  end
end
