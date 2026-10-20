# frozen_string_literal: true

module Spree
  module Api
    module V3
      class StockMovementSerializer < BaseSerializer
        # `kind` is nullable for the lifetime of 6.0: a legacy row on an
        # install that has not run spree:migrate_stock_movements_to_typed_rows
        # has no kind yet.
        typelize quantity: :number, kind: [:string, nullable: true, enum: Spree::StockMovement::KINDS],
                 reason: [:string, nullable: true], stock_level_id: [:string, nullable: true]

        attributes :quantity, :kind, :reason,
                   created_at: :iso8601, updated_at: :iso8601

        prefixed_id_attributes :stock_level
      end
    end
  end
end
