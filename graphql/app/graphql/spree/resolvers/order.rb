module Spree
  module Resolvers
    class Order < Base
      def all(object, arguments, context)
        if authorize?(:read, ::Spree::Order)
          page = arguments[:page] || 0
          per_page = arguments[:perPage] || Spree::Config[:admin_orders_per_page]
          per_page = Spree::Config[:admin_orders_per_page] if per_page > Spree::Config[:admin_orders_per_page]
          params = { page: page, per_page: per_page }
          collection_paginator.new(collection_finder.new.execute, params).call
        else
          ::Spree::Order.none
        end
      end

      def current(object, arguments, context)
        spree_current_order
      end


      private

      # @return ::Spree::Shared::Paginate
      def collection_paginator
        Spree::Graphql::Dependencies.graphql_collection_paginator.constantize
      end

      # @return ::Spree::Order::FindComplete
      def collection_finder
        Spree::Graphql::Dependencies.graphql_completed_order_finder.constantize
      end
    end
  end
end
