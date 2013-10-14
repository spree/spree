module Spree
  module Admin
    module StockMovementsHelper
      def pretty_originator(stock_movement)
        if stock_movement.originator.respond_to?(:number)
          stock_movement.originator.number
        else
          ""
        end
      end

      def display_variant(stock_movement)
        variant = stock_movement.stock_item.variant
        output = variant.name
        output += "<br>(#{variant.options_text})" unless variant.options_text.blank?
        output.html_safe
      end
    end
  end
end
