module Spree
  module Orders
    class Cancel
      prepend Spree::ServiceModule::Base

      def call(order:, canceler: nil, canceled_at: nil)
        canceled_at ||= Time.current

        order.transaction do
          changes = { canceled_at: canceled_at }
          changes[:canceler_id] = canceler.id if canceler.present?
          order.update_columns(changes)
          order.cancel!
        end

        order.publish_event('order.canceled')
        success(order.reload)
      rescue ActiveRecord::Rollback, ActiveRecord::RecordInvalid, StateMachines::InvalidTransition
        failure(order)
      end
    end
  end
end
