module Spree
  class OrderMerger
    attr_accessor :order
    delegate :updater, to: :order

    def initialize(order)
      @order = order
    end

    def merge!(other_order, user = nil)
      other_order.line_items.each do |other_order_line_item|
        next unless other_order_line_item.currency == order.currency

        current_line_item = find_matching_line_item(other_order_line_item)
        handle_merge(current_line_item, other_order_line_item)
      end

      set_user(user)
      persist_merge

      # So that the destroy doesn't take out line items which may have been re-assigned
      other_order.line_items.reload
      other_order.destroy
    end

    # Compare the line item of the other order with mine.
    # Make sure you allow any extensions to chime in on whether or
    # not the extension-specific parts of the line item match
    def find_matching_line_item(other_order_line_item)
      order.line_items.detect do |my_li|
        my_li.variant == other_order_line_item.variant &&
          CompareLineItems.new.call(order: order, line_item: my_li, options: other_order_line_item.serializable_hash).value
      end
    end

    def set_user(user = nil)
      order.associate_user!(user) if !order.user && !user.blank?
    end

    # The idea is the end developer can choose to override the merge
    # to their own choosing. Default is merge with errors.
    def handle_merge(current_line_item, other_order_line_item)
      if current_line_item
        current_line_item.quantity += other_order_line_item.quantity
        handle_error(current_line_item) unless current_line_item.save
      else
        other_order_line_item.order_id = order.id
        handle_error(other_order_line_item) unless other_order_line_item.save
      end
    end

    # Change the error messages as you choose.
    def handle_error(line_item)
      order.errors[:base] << line_item.errors.full_messages
    end

    def persist_merge
      updater.update_item_count
      updater.update_item_total
      updater.persist_totals
    end
  end
end
