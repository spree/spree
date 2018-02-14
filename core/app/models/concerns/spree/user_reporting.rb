module Spree
  module UserReporting
    extend DisplayMoney
    money_methods :lifetime_value, :average_order_value

    def lifetime_value
      orders.complete.sum(:total)
    end

    def order_count
      orders.complete.size
    end

    def average_order_value
      if order_count > 0
        lifetime_value / order_count
      else
        BigDecimal('0.00')
      end
    end
  end
end
