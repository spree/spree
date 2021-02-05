module Spree
  module Types
    class MutationType < ::GraphQL::Schema::Object
      graphql_name "Mutation"

      field :cart, mutation: ::Spree::Mutations::Cart

      # field :add_item, [OrderType], null: false, mutation: Resolvers::Order[:add_item]

    end
  end
end
