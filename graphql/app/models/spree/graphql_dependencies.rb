module Spree
  class GraphqlDependencies
    include Spree::DependenciesHelper

    INJECTION_POINTS = [
      :graphql_order_sorter, :graphql_products_sorter, :graphql_collection_paginator,
      :graphql_completed_order_finder, :graphql_current_order_finder, :graphql_products_finder
    ].freeze

    attr_accessor *INJECTION_POINTS

    def initialize
      set_graphql_defaults
    end

    private

    def set_graphql_defaults
      # sorters
      @graphql_order_sorter = Spree::Dependencies.order_sorter
      @graphql_products_sorter = Spree::Dependencies.products_sorter

      # paginators
      @graphql_collection_paginator = Spree::Dependencies.collection_paginator

      # finders
      @graphql_current_order_finder = Spree::Dependencies.current_order_finder
      @graphql_completed_order_finder = Spree::Dependencies.completed_order_finder

      @graphql_products_finder = Spree::Dependencies.products_finder
    end
  end
end
