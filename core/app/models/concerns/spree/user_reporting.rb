module Spree
  module UserReporting
    def display_lifetime_value(store: Store.default, currency: store.default_curremcy)
      Spree::Money.new(lifetime_value(store: store, currency: currency), currency: currency)
    end

    def lifetime_value(**args)
      order_calculate(**args,
                      operation: :sum,
                      column: :total)
    end

    def display_average_order_value(store: Store.default, currency: store.default_currency)
      Spree::Money.new(average_order_value(store: store, currency: currency), currency: currency)
    end

    def average_order_value(**args)
      order_calculate(**args,
                      operation: :average,
                      column: :total)
    end

    def order_count(store = nil)
      store ||= Store.default
      order_calculate(store: store,
                      currency: store.supported_currencies.split(','),
                      operation: :count,
                      column: :all)
    end

    def order_calculate(store:, currency:, operation:, column:)
      store.orders.complete.where(currency: currency).calculate(operation, column)
    end
  end
end
