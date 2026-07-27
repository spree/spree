# frozen_string_literal: true

module Spree
  module Api
    module V3
      class StockMovementSerializer < BaseSerializer
        typelize quantity: :number, action: [:string, nullable: true],
                 originator_type: [:string, nullable: true], originator_id: [:string, nullable: true],
                 stock_item_id: [:string, nullable: true]

        attributes :quantity, :action,
                   created_at: :iso8601, updated_at: :iso8601

        # `"shipment"` / `"stock_transfer"`, not the polymorphic class name.
        attribute :originator_type do |movement|
          Spree::Base.polymorphic_api_type(movement.originator_type)
        end

        attribute :originator_id do |movement|
          movement.originator&.prefixed_id
        end

        attribute :stock_item_id do |movement|
          movement.stock_item&.prefixed_id
        end
      end
    end
  end
end
