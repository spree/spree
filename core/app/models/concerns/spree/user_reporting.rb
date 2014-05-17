module Spree
  module UserReporting
    def lifetime_value
      spree_orders.complete.pluck(:total).sum
    end

    def display_lifetime_value
      Spree::Money.new(lifetime_value)
    end

    def order_count
      BigDecimal(spree_orders.complete.count)
    end

    def average_order_value
      if order_count.to_i > 0
        lifetime_value / order_count
      else
        BigDecimal("0.00")
      end
    end

    def display_average_order_value
      Spree::Money.new(average_order_value)
    end
  end
end
