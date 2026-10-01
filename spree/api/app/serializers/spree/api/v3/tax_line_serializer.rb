module Spree
  module Api
    module V3
      # A single tax charge (typed row) on a line item, fulfillment or fee —
      # or, after the sale, the tax a return, claim or exchange line gives
      # back (`credit`) or charges on an exchange's replacement.
      class TaxLineSerializer < BaseSerializer
        typelize label: :string, rate: :string, included: :boolean, credit: :boolean,
                 amount: [:string, nullable: true], display_amount: [:string, nullable: true],
                 tax_rate_id: [:string, nullable: true], line_item_id: [:string, nullable: true],
                 fulfillment_id: [:string, nullable: true], fee_id: [:string, nullable: true],
                 return_line_item_id: [:string, nullable: true], claim_line_item_id: [:string, nullable: true],
                 exchange_line_item_id: [:string, nullable: true]

        attributes :label, :included, :credit

        attribute :rate do |record|
          record.rate&.to_s
        end

        attribute :tax_rate_id do |record|
          record.tax_rate&.prefixed_id
        end

        attribute :line_item_id do |record|
          record.line_item&.prefixed_id
        end

        attribute :fulfillment_id do |record|
          record.fulfillment&.prefixed_id
        end

        attribute :fee_id do |record|
          record.fee&.prefixed_id
        end

        attribute :return_line_item_id do |record|
          record.return_line_item&.prefixed_id
        end

        attribute :claim_line_item_id do |record|
          record.claim_line_item&.prefixed_id
        end

        attribute :exchange_line_item_id do |record|
          record.exchange_line_item&.prefixed_id
        end

        money_attributes :amount, :display_amount
      end
    end
  end
end
