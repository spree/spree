module Spree
  module OrderChanges
    # Opens a change set, adds every action, requests it and — unless told
    # otherwise — confirms it, all or nothing. This is how a caller that
    # already knows the whole change uses the substrate: the admin order edit
    # screen on Save, and the return, exchange and claim workflows. Each step
    # is still the workflow an extension hooks into.
    class Apply
      prepend Spree::ServiceModule::Base

      # Replacements the confirmed set shipped, read off the instance:
      # `service = Spree.order_change_apply_service.new; service.call(...); service.fulfillments`.
      # @return [Array<Spree::Fulfillment>]
      attr_reader :fulfillments

      # @param order [Spree::Order]
      # @param actions [Array<Hash>] keyword arguments for
      #   Spree::OrderChanges::AddAction (`kind:`, `line_item:`, `variant:`, `quantity:`…)
      # @param requested_by [Object, nil]
      # @param post_sale_record [Spree::Return, Spree::Exchange, Spree::Claim, nil]
      # @param confirm [Boolean] false leaves the set requested, for a later
      #   confirm or cancel
      # @param metadata [Hash]
      # @return [Spree::ServiceModule::Result] value is the change set
      def call(order:, actions:, requested_by: nil, post_sale_record: nil, confirm: true, metadata: {})
        @fulfillments = []
        failed = nil
        order_change = nil

        # requires_new: a failure rolls back to here and leaves no open set
        # behind, whatever transaction the caller holds.
        ApplicationRecord.transaction(requires_new: true) do
          begun, failed = run_workflow(Spree.order_change_begin_workflow,
                                       order: order, requested_by: requested_by,
                                       post_sale_record: post_sale_record, metadata: metadata)
          raise ActiveRecord::Rollback if failed

          order_change = begun.order_change
          Array(actions).each do |attributes|
            _added, failed = run_workflow(Spree.order_change_add_action_workflow,
                                          order_change: order_change, **attributes.to_h.symbolize_keys)
            raise ActiveRecord::Rollback if failed
          end

          _requested, failed = run_workflow(Spree.order_change_request_workflow, order_change: order_change)
          raise ActiveRecord::Rollback if failed

          if confirm
            confirmed, failed = run_workflow(Spree.order_change_confirm_workflow, order_change: order_change)
            raise ActiveRecord::Rollback if failed

            @fulfillments = confirmed.fulfillments
          end
        end

        failed || success(order_change)
      end

      private

      # @return [Array(Spree::Workflow, Spree::ServiceModule::Result | nil)]
      #   the workflow that ran, and its result when it failed
      def run_workflow(workflow, **arguments)
        instance = workflow.new
        result = instance.call(**arguments)
        [instance, (result if result.failure?)]
      end
    end
  end
end
