module Spree
  class Order < Spree::Base
    module Digital
      def digital?
        line_items.all?(&:digital?)
      end

      def some_digital?
        line_items.any?(&:digital?)
      end

      def digital_line_items
        line_items.select(&:digital?)
      end

      def digital_links
        digital_line_items.map(&:digital_links).flatten
      end

      def reset_digital_links!
        digital_links.each(&:reset!)
      end
    end
  end
end
