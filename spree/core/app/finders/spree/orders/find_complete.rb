module Spree
  module Orders
    class FindComplete
      include Spree::Orders::FinderHelper

      attr_reader :user, :number, :prefix_id, :param, :token, :store, :email

      def initialize(user: nil, number: nil, prefix_id: nil, param: nil, token: nil, store: nil, email: nil)
        @user = user
        @number = number
        @prefix_id = prefix_id
        @param = param
        @token = token
        @store = store
        @email = email
      end

      def execute
        orders = by_user(scope)
        orders = by_number(orders)
        orders = by_prefix_id(orders)
        orders = by_param(orders)
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

      def prefix_id?
        prefix_id.present?
      end

      def param?
        param.present?
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

      def by_prefix_id(orders)
        return orders unless prefix_id?

        decoded = Spree::Order.decode_prefixed_id(prefix_id)
        orders.where(id: decoded)
      end

      # Find by param - tries prefixed ID first, then number for backwards compatibility
      def by_param(orders)
        return orders unless param?

        decoded = Spree::Order.decode_prefixed_id(param)
        if decoded
          orders.where(id: decoded)
        else
          orders.where(number: param)
        end
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
