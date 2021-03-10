module Spree
  module Admin
    module StockMovementsHelper
      def pretty_originator(stock_movement)
        if stock_movement.originator.respond_to?(:number)
          if stock_movement.originator.respond_to?(:order)
            link_to stock_movement.originator.number, [:edit, :admin, stock_movement.originator.order]
          elsif stock_movement.originator.is_a?(Spree::StockTransfer)
            link_to stock_movement.originator.number, spree.admin_stock_transfer_url(stock_movement.originator)
          else
            stock_movement.originator.number
          end
        else
          ''
        end
      end

      def display_variant(stock_movement)
        variant = stock_movement.stock_item.variant
        output = [variant.name]
        output << variant.options_text unless variant.options_text.blank?
        safe_join(output, '<br />'.html_safe)
      end
    end
  end
end
