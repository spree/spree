module Spree
  module Orders
    class FindComplete
      attr_reader :user, :number, :token

      def initialize(user: nil, number: nil, token: nil)
        @user = user
        @number = number
        @token = token
      end

      def execute
        orders = by_user(scope)
        orders = by_number(orders)
        orders = by_token(orders)

        orders
      end

      private

      def scope
        user? ? user.orders.complete.includes(scope_includes) : Spree::Order.complete.includes(scope_includes)
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

      def scope_includes
        {
          line_items: [
            variant: [
              :images,
              option_values: :option_type,
              product: :product_properties,
            ]
          ]
        }
      end
    end
  end
end
