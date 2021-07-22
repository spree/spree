module Spree
  module UserReporting
    extend DisplayMoney
    money_methods :lifetime_value, :average_order_value

    def lifetime_value(*args)
      order_calculate(*args,
                      operation: :sum,
                      column: :total)
    end

    def average_order_value(*args)
      order_calculate(*args,
                      operation: :average,
                      column: :total)
    end

    def order_count(store = nil)
      store ||= Store.default
      order_calculate(store,
                      store.supported_currencies.split(','),
                      operation: :count,
                      column: :all)
    end

    private

    def order_calculate(store = nil, currency = nil, operation:, column:)
      store ||= Store.default
      currency ||= store.default_currency
      store.orders.complete.where(currency: currency).calculate(operation, column) || BigDecimal('0.00')
    end
  end
end
