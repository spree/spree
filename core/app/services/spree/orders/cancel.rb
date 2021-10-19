module Spree
  module Orders
    class Cancel
      prepend Spree::ServiceModule::Base

      def call(order:, canceler: nil)
        if canceler.present?
          order.canceled_by(canceler)
        else
          order.cancel!
        end
        success(order.reload)
      rescue ActiveRecord::Rollback, ActiveRecord::RecordInvalid, StateMachines::InvalidTransition
        failure(order)
      end
    end
  end
end
