module Spree
  module Resolvers
    class Product < Base
      def all(object, arguments, context)
        if authorize?(:read, ::Spree::Product)
          page = arguments[:page] || 0
          finder_params = arguments[:params] || {}
          currency = Spree::Config[:currency] || arguments[:currency]
          per_page = arguments[:per_page] || Spree::Config[:products_per_page]
          per_page = Spree::Config[:products_per_page] if per_page > Spree::Config[:products_per_page]
          pagination_params = { page: page, per_page: per_page }
          collection_paginator.new(collection_finder.new(scope: ::Spree::Product.all, params: finder_params, current_currency: currency).execute, pagination_params).call
        else
          Spree::Product.none
        end
      end

      private

      # @return ::Spree::Shared::Paginate
      def collection_paginator
        Spree::Graphql::Dependencies.graphql_collection_paginator.constantize
      end

      # @return ::Spree::Products::Find
      def collection_finder
        Spree::Graphql::Dependencies.graphql_products_finder.constantize
      end
    end
  end
end
