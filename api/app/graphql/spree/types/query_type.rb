module Spree
  module Types
    class QueryType < ::GraphQL::Schema::Object
      graphql_name "Query"

      field :orders, [OrderType], 'Returns all orders', null: false, resolve: Resolvers::Order[:all] do
        argument :per_page, Integer, required: false
        argument :page, Integer, required: false
      end

      field :current_order, OrderType, 'Return current order', null: false, resolve: Resolvers::Order[:current]

      field :products, [ProductType], 'Returns all products', null: false, resolve: Resolvers::Product[:all] do
        argument :per_page, Integer, required: false
        argument :page, Integer, required: false
      end

      # You can only see the details on a `Friendship`
      # if you're one of the people involved in it.
    end
  end
end
