module Spree
  module Api
    module V3
      module Admin
        class TaxLineSerializer < V3::TaxLineSerializer
          typelize order_id: :string,
                   line_item_id: [:string, nullable: true],
                   fulfillment_id: [:string, nullable: true]

          attributes created_at: :iso8601, updated_at: :iso8601

          attribute :order_id do |tax_line|
            tax_line.order&.prefixed_id
          end

          attribute :line_item_id do |tax_line|
            tax_line.line_item&.prefixed_id
          end

          attribute :fulfillment_id do |tax_line|
            tax_line.fulfillment&.prefixed_id
          end
        end
      end
    end
  end
end
