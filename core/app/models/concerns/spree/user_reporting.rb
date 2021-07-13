module Spree
  module UserReporting

    def display_lifetime_value(store)
      Spree::Money.new(lifetime_value(store), currency: store.default_currency)
    end

    def lifetime_value(store)
      orders.complete.where(store: store).sum(:total)
    end

    def display_average_order_value(store)
      Spree::Money.new(average_order_value(store), currency: store.default_currency)
    end

    def average_order_value(store)
      orders.complete.where(store: store).average(:total)
    end

    def order_count(store)
      orders.complete.where(store: store).size
    end
  end
end
