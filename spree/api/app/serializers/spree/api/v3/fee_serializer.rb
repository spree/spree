module Spree
  module Api
    module V3
      # An extensible charge (typed row): surcharge, handling, gift wrap, COD.
      # Order-level when both adjustable IDs are null.
      class FeeSerializer < BaseSerializer
        typelize label: :string, kind: :string,
                 amount: [:string, nullable: true], display_amount: [:string, nullable: true],
                 line_item_id: [:string, nullable: true], fulfillment_id: [:string, nullable: true]

        attributes :label, :kind

        attribute :line_item_id do |record|
          record.line_item&.prefixed_id
        end

        attribute :fulfillment_id do |record|
          record.fulfillment&.prefixed_id
        end

        money_attributes :amount, :display_amount
      end
    end
  end
end
