module Spree
  module OrderChanges
    # Writes a change set's actions to its order and re-sums it — what Confirm
    # runs for real and Preview runs inside a transaction it rolls back. Opens
    # no transaction: both callers hold one around it.
    #
    # Actions apply grouped by kind, item edits first, so a batch of item
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
          records: order_change.actions.to_a, associations: [:line_item, :variant, :fulfillment, :delivery_method, :discount]
        ).call
        step :apply_item_actions
        step :apply_discount_actions
        step :apply_receive_actions
        step :apply_fulfillment_actions
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

        # A line edited or removed some other way since the set was requested:
        # applying by its variant would quietly re-add what was taken away.
        failure(order_change, :order_change_line_item_gone) if actions.any? { |action| action.line_item_id && action.line_item.nil? }

        quantities = order.line_items.to_h { |line_item| [line_item.variant_id, line_item.quantity] }
        targets = {}
        actions.each do |action|
          variant_id = action.kind == 'add_item' ? action.variant_id : action.line_item.variant_id
          current = targets.fetch(variant_id) { quantities.fetch(variant_id, 0) }
          targets[variant_id] =
            case action.kind
            when 'add_item' then current + action.quantity
            when 'update_item' then action.quantity
            when 'remove_item' then 0
            end
        end

        items = targets.map { |variant_id, quantity| { variant_id: variant_id, quantity: quantity } }
        result = Spree::Orders::UpsertItems.call(order: order, items: items)
        link_added_lines(actions) if result.success?
        result
      end

      # Records the line each add landed on, so the set says which line it
      # created or topped up and a client can edit that line by its id.
      def link_added_lines(actions)
        lines = order.line_items.reload.index_by(&:variant_id)
        actions.each do |action|
          next unless action.kind == 'add_item' && action.line_item_id.nil?

          line_item = lines[action.variant_id]
          action.update!(line_item: line_item) if line_item
        end
      end

      # After the item edits, so an order-level discount is spread over the
      # lines as they end up. Through the same services as the discounts
      # endpoints, so a discount reads the same however it was made.
      def apply_discount_actions
        actions = actions_of(*Spree::OrderChangeAction::DISCOUNT_KINDS)
        return if actions.empty?

        # A line removed by this change, or since it was requested, takes its
        # discounts with it; a discount written to it would outlive the line.
        line_item_ids = order.line_items.ids
        discount_ids = order.discounts.ids
        gone = actions.any? do |action|
          (action.line_item_id && line_item_ids.exclude?(action.line_item_id)) ||
            (action.discount_id && discount_ids.exclude?(action.discount_id))
        end
        failure(order_change, :order_change_line_item_gone) if gone

        actions.sort_by(&:position).each do |action|
          result = apply_discount_action(action)
          return result if result.failure?
        end
        nil
      end

      def apply_discount_action(action)
        case action.kind
        when 'add_discount'
          Spree.order_discount_create_service.call(order: order, label: action.label, value: action.value,
                                                   value_type: action.value_type, line_item: action.line_item)
        when 'update_discount'
          Spree.order_discount_update_service.call(order: order, discount: action.discount,
                                                   attributes: { label: action.label, amount: action.amount }.compact)
        when 'remove_discount'
          Spree.order_discount_destroy_service.call(order: order, discount: action.discount)
        end
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
    end
  end
end
