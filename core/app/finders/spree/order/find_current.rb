module Spree
  class Order < Spree::Base
    class FindCurrent
      def execute(user:, store:, **params)
        params = params.merge(store_id: store.id)

        order = incomplete_orders.find_by(params)

        return order unless order.nil?
        return if user.nil?

        incomplete_orders.order(created_at: :desc).find_by(store: store, user: user)
      end

      private

      def incomplete_orders
        Spree::Order.incomplete.includes(line_items: [variant: [:images, :option_values, :product]])
      end
    end
  end
end
