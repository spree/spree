# frozen_string_literal: true

module Spree
  module Api
    module V3
      class StockLevelSerializer < BaseSerializer
        typelize count_on_hand: :number, backorderable: :boolean,
                 stock_location_id: [:string, nullable: true], variant_id: [:string, nullable: true]

        attributes :count_on_hand, :backorderable

        prefixed_id_attributes :stock_location, :variant
      end
    end
  end
end
