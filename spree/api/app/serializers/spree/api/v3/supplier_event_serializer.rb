module Spree
  module Api
    module V3
      # Payload of the supplier.* events. Suppliers have no storefront
      # serializer — a customer never sees who the merchant buys from — so the
      # event shape is declared here rather than found by convention.
      class SupplierEventSerializer < Admin::SupplierSerializer
      end
    end
  end
end
