module Spree
  module Orders
    class FindComplete
      include Spree::Orders::FinderHelper

      attr_reader :user, :number, :token, :store

      def initialize(user: nil, number: nil, token: nil, store: nil)
        @user = user
        @number = number
        @token = token
        @store = store
      end

      def execute
        orders = by_user(scope)
        orders = by_number(orders)
        orders = by_token(orders)
        orders = by_store(orders)

        orders
      end

      private

      def scope
        user? ? user.orders.complete.includes(order_includes) : Spree::Order.complete.includes(order_includes)
      end

      def user?
        user.present?
      end

      def number?
        number.present?
      end

      def token?
        token.present?
      end

      def store?
        store.present?
      end

      def by_user(orders)
        return orders unless user?

        orders
      end

      def by_number(orders)
        return orders unless number?

        orders.where(number: number)
      end

      def by_token(orders)
        return orders unless token?

        orders.where(token: token)
      end

      def by_store(orders)
        return orders unless store?

        orders.where(store: store)
      end
    end
  end
end
