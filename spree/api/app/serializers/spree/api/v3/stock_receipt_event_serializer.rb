module Spree
  module Api
    module V3
      # Payload of the stock_receipt.* events. The counted lines and who
      # received them stay behind the Admin API.
      class StockReceiptEventSerializer < BaseSerializer
        typelize number: :string,
                 received_at: :string,
                 receivable_type: [:string, enum: %w[purchase_order stock_transfer]],
                 receivable_id: :string,
                 quantity_accepted_total: :number,
                 quantity_rejected_total: :number

        attributes :number, :quantity_accepted_total, :quantity_rejected_total,
                   received_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

        attribute :receivable_type do |receipt|
          receipt.receivable_type.demodulize.underscore
        end

        attribute :receivable_id do |receipt|
          receipt.receivable&.prefixed_id
        end
      end
    end
  end
end
