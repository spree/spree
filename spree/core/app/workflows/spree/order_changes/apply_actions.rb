module Spree
  module OrderChanges
    # Writes a change set's actions to its order and re-sums it — what Confirm
    # runs for real and Preview runs inside a transaction it rolls back. Opens
    # no transaction: both callers hold one around it.
    #
    # Core kinds apply grouped by kind, item edits first, so a batch of item
    # edits goes through Spree::Orders::UpsertItems once — one validate pass,
    # one stock check — exactly as an order update does. Appliers never derive
    # a unit price: a negotiated line keeps its price through any edit.
    class ApplyActions < Spree::Workflow
      include Spree::Fulfillments::Replacements

      # @param order_change [Spree::OrderChange]
      # @return [Spree::ServiceModule::Result] value is the fulfillments created
      def perform(order_change:)
        super

        @fulfillments = []
        # Confirm re-reads the set under its lock, so its actions arrive
        # unloaded; one query per association rather than one per action.
        ActiveRecord::Associations::Preloader.new(
          records: order_change.actions.to_a, associations: [:line_item, :variant, :fulfillment, :delivery_method]
        ).call
        step :apply_item_actions
        step :apply_receive_actions
        step :apply_fulfillment_actions
        step :apply_registered_actions
        order.recalculate_totals! if order_change.moves_money?

        success(@fulfillments)
      end

      private

      def order
        order_change.order
      end

      def actions_of(*kinds)
        order_change.actions.select { |action| kinds.include?(action.kind) }
      end

      # Collapses the item actions into the quantity each variant ends at,
      # which is what the upsert takes: an add on a variant the order
      # already carries tops that line up rather than adding a second one.
      def apply_item_actions
        actions = actions_of(*Spree::OrderChangeAction::ITEM_KINDS)
        return if actions.empty?

        quantities = order.line_items.to_h { |line_item| [line_item.variant_id, line_item.quantity] }
        targets = {}
        actions.each do |action|
          variant_id = action.line_item&.variant_id || action.variant_id
          current = targets.fetch(variant_id) { quantities.fetch(variant_id, 0) }
          targets[variant_id] =
            case action.kind
            when 'add_item' then current + action.quantity
            when 'update_item' then action.quantity
            when 'remove_item' then 0
            end
        end

        items = targets.map { |variant_id, quantity| { variant_id: variant_id, quantity: quantity } }
        Spree::Orders::UpsertItems.call(order: order, items: items)
      end

      # Puts resellable goods back on the shelf at the location the return or
      # exchange named, recorded against it.
      def apply_receive_actions
        actions = actions_of('receive_item')
        return if actions.empty?

        record = order_change.post_sale_record
        actions.each { |action| record.stock_location.restock(action.variant, action.quantity, record) }
      end

      # One stock coordination for every replacement, so units that can ship
      # together go out in one parcel.
      def apply_fulfillment_actions
        actions = actions_of('add_fulfillment')
        return if actions.empty?

        items = actions.map do |action|
          { variant: action.variant, quantity: action.quantity, line_item: action.line_item }
        end

        @fulfillments = build_replacements(order_change.post_sale_record, items)
      end

      def apply_registered_actions
        order_change.actions.each do |action|
          applier = Spree::OrderChange.action_appliers[action.kind]
          applier&.constantize&.new&.call(order_change: order_change, action: action)
        end
      end
    end
  end
end
