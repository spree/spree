module Spree
  module UserReporting
    extend DisplayMoney
    money_methods :lifetime_value, :average_order_value

    def report_values_for(report_name, store)
      store ||= Store.default

      completed_orders_for_store(store).pluck(:currency).uniq.each_with_object([]) do |currency, arr|
        arr << send("display_#{report_name}", store: store, currency: currency)
      end
    end

    def lifetime_value(**args)
      order_calculate(operation: :sum,
                      column: :total,
                      **args)
    end

    def average_order_value(**args)
      order_calculate(operation: :average,
                      column: :total,
                      **args)
    end

    def order_count(store = nil)
      store ||= Store.default
      order_calculate(store: store,
                      currency: store.supported_currencies.split(','),
                      operation: :count,
                      column: :all)
    end

    def amount_spent_in(currency)
      completed_orders.where(currency: currency).sum(:total)
    end

    def display_amount_spent_in(currency)
      Money.new(amount_spent_in(currency), currency: currency).to_html
    end

    def completed_orders_for_store(store)
      orders.for_store(store).complete.order(currency: :desc)
    end

    private

    def order_calculate(operation:, column:, store: nil, currency: nil)
      store ||= Store.default
      currency ||= store.default_currency

      completed_orders_for_store(store).where(currency: currency).calculate(operation, column) || BigDecimal('0.00')
    end
  end
end
