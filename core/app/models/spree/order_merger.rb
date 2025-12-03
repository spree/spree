module Spree
  class OrderMerger
    attr_accessor :order
    delegate :updater, to: :order

    def initialize(order)
      @order = order
    end

    def merge!(other_order, user = nil, discard_merged: true)
      handle_gift_card(other_order)
      other_order.line_items.each do |other_order_line_item|
        next unless other_order_line_item.currency == order.currency

        current_line_item = find_matching_line_item(other_order_line_item)
        handle_merge(current_line_item, other_order_line_item)
      end

      set_user(user)
      clear_addresses(other_order) if discard_merged
      persist_merge

      if discard_merged
        # So that the destroy doesn't take out line items which may have been re-assigned
        other_order.line_items.reload
        other_order.destroy
      end
    end

    private

    # Compare the line item of the other order with mine.
    # Make sure you allow any extensions to chime in on whether or
    # not the extension-specific parts of the line item match
    def find_matching_line_item(other_order_line_item)
      order.line_items.detect do |my_li|
        my_li.variant == other_order_line_item.variant &&
          Spree.cart_compare_line_items_service.new.call(order: order,
                                                         line_item: my_li,
                                                         options: other_order_line_item.serializable_hash).value
      end
    end

    def set_user(user = nil)
      order.associate_user!(user) if !order.user && !user.blank?
    end

    def clear_addresses(other_order)
      other_order.ship_address = nil
      other_order.bill_address = nil
    end

    # The idea is the end developer can choose to override the merge
    # to their own choosing. Default is merge with errors.
    def handle_merge(current_line_item, other_order_line_item)
      if current_line_item
        current_line_item.quantity += other_order_line_item.quantity
        handle_error(current_line_item) unless current_line_item.save
      else
        order.line_items << other_order_line_item
        other_order_line_item.adjustments.update_all(order_id: order.id)
        handle_error(other_order_line_item) unless other_order_line_item.save
      end
    end

    # Change the error messages as you choose.
    def handle_error(line_item)
      order.errors.add(:base, line_item.errors.full_messages)
    end

    def persist_merge
      updater.update
    end

    def handle_gift_card(other_order)
      return unless other_order.gift_card.present?

      gift_card = other_order.gift_card

      other_order.remove_gift_card
      order.apply_gift_card(gift_card)
    end
  end
end
