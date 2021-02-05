module Spree
  module Mutations
    class  Cart < BaseMutation
      type ::Spree::Types::OrderType

      def action
        ::Spree::Order.create
      end

      def default
        ::Spree::Order.none
      end

      def authorize_args
        [:create, ::Spree::Order]
      end
    end
  end
end
