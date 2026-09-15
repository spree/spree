module Spree
  module Api
    module V3
      # Payload of the stock_receipt.* events. Stock receipts have no
      # storefront serializer, so the event shape is declared here rather than
      # found by convention.
      class StockReceiptEventSerializer < Admin::StockReceiptSerializer
      end
    end
  end
end
