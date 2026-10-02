# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Seller
        # One line of an exchange — what came back and what goes out in its
        # place. Both variants expand through the seller's own serializer.
        class ExchangeLineItemSerializer < V3::ExchangeLineItemSerializer
          typelize name: [:string, nullable: true],
                   new_variant_name: [:string, nullable: true]

          attribute :name do |line|
            line.line_item&.name || line.original_variant&.name
          end

          attribute :new_variant_name do |line|
            line.new_variant&.name
          end

          expandable :one, :original_variant, :seller_variant_serializer
          expandable :one, :new_variant, :seller_variant_serializer
        end
      end
    end
  end
end
