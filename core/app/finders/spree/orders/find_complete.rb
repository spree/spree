module Spree
  module Orders
    class FindComplete
      include Spree::Orders::FinderHelper

      attr_reader :user, :number, :token, :store, :email

      def initialize(user: nil, number: nil, token: nil, store: nil, email: nil)
        @user = user
        @number = number
        @token = token
        @store = store
        @email = email
      end

      def execute
        orders = by_user(scope)
        orders = by_number(orders)
        orders = by_token(orders)
        orders = by_store(orders)
        orders = by_email(orders)

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

      def email?
        email.present?
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

      def by_email(orders)
        return orders unless email?

        orders.where(email: email.strip.downcase)
      end
    end
  end
end
