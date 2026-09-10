module Spree
  module Api
    module V3
      # Payload of the purchase_order.* events. Purchase orders have no
      # storefront serializer, so the event shape is declared here rather than
      # found by convention.
      class PurchaseOrderEventSerializer < Admin::PurchaseOrderSerializer
      end
    end
  end
end
