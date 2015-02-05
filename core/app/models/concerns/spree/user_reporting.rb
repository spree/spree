module Spree
  module UserReporting
    extend DisplayMoney
    money_methods :lifetime_value, :average_order_value

    def lifetime_value
      orders.complete.pluck(:total).sum
    end

    def order_count
      BigDecimal(orders.complete.count)
    end

    def average_order_value
      if order_count.to_i > 0
        lifetime_value / order_count
      else
        BigDecimal("0.00")
      end
    end
  end
end
