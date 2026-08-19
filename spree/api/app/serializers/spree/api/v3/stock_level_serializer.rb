# frozen_string_literal: true

module Spree
  module Api
    module V3
      class StockLevelSerializer < BaseSerializer
        typelize count_on_hand: :number, backorderable: :boolean,
                 stock_location_id: [:string, nullable: true], variant_id: [:string, nullable: true]

        attributes :count_on_hand, :backorderable

        attribute :stock_location_id do |stock_level|
          stock_level.stock_location&.prefixed_id
        end

        attribute :variant_id do |stock_level|
          stock_level.variant&.prefixed_id
        end
      end
    end
  end
end
