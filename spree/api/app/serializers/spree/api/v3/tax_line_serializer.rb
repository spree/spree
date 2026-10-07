module Spree
  module Api
    module V3
      # A single tax charge (typed row) on a line item, fulfillment or fee —
      # or, after the sale, the tax a return, claim or exchange line gives
      # back (`credit`) or charges on an exchange's replacement.
      class TaxLineSerializer < BaseSerializer
        typelize label: :string, rate: :string, included: :boolean, credit: :boolean,
                 tax_rate_id: [:string, nullable: true], line_item_id: [:string, nullable: true],
                 fulfillment_id: [:string, nullable: true], fee_id: [:string, nullable: true],
                 return_line_item_id: [:string, nullable: true], claim_line_item_id: [:string, nullable: true],
                 exchange_line_item_id: [:string, nullable: true]

        attributes :label, :included, :credit

        attribute :rate do |record|
          record.rate&.to_s
        end

        prefixed_id_attributes :tax_rate, :line_item, :fulfillment, :fee, :return_line_item, :claim_line_item,
                               :exchange_line_item

        money_attributes :amount, :display_amount
      end
    end
  end
end
