module Spree
  module Api
    module V3
      # An extensible charge (typed row): surcharge, handling, gift wrap, COD.
      # Order-level when both adjustable IDs are null.
      class FeeSerializer < BaseSerializer
        typelize label: :string,
                 kind: [:string, enum: Spree::Fee::KINDS, enum_type_name: 'FeeKind',                         comment: 'What sort of charge this is. `duty` is a customs duty on a cross-border order and is not taxed; the other kinds are. Extensions may register further kinds.'],
                 line_item_id: [:string, nullable: true], fulfillment_id: [:string, nullable: true]

        attributes :label, :kind

        prefixed_id_attributes :line_item, :fulfillment

        money_attributes :amount, :display_amount
      end
    end
  end
end
