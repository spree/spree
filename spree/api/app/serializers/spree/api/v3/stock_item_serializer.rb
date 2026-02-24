# frozen_string_literal: true

module Spree
  module Api
    module V3
      class StockItemSerializer < BaseSerializer
        typelize count_on_hand: :number, backorderable: :boolean,
                 stock_location_id: [:string, nullable: true], variant_id: [:string, nullable: true]

        attributes :count_on_hand, :backorderable,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :stock_location_id do |stock_item|
          stock_item.stock_location&.prefixed_id
        end

        attribute :variant_id do |stock_item|
          stock_item.variant&.prefixed_id
        end
      end
    end
  end
end
