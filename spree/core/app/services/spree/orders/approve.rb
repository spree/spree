module Spree
  module Orders
    class Approve
      prepend Spree::ServiceModule::Base

      # Approves an order: clears the risk flag and records who approved it and when.
      #
      # @param order [Spree::Order]
      # @param approver [Object, nil] who approved it — an admin user or an
      #   API key (see Spree.actor_classes)
      # @param level [String, nil] deprecated and ignored — removed in Spree 6.1
      # @param note [String, nil] deprecated and ignored — removed in Spree 6.1
      # @return [Spree::ServiceModule::Result]
      def call(order:, approver: nil, level: nil, note: nil)
        if level.present? || note.present?
          Spree::Deprecation.warn('Spree::Orders::Approve no longer accepts level or note — they were never read and will be removed in Spree 6.1.')
        end

        changes = { considered_risky: false, approved_at: Time.current }
        # Both halves together: the actor is polymorphic, so an id without its
        # type names nothing (see docs/plans/6.0-action-actors.md).
        if approver.present?
          changes[:approver_id] = approver.id
          changes[:approver_type] = approver.class.polymorphic_name
        end
        order.update_columns(changes)

        order.publish_event('order.approved')
        success(order.reload)
      end
    end
  end
end
