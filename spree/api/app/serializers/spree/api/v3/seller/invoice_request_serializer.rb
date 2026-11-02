module Spree
  module Api
    module V3
      module Seller
        # What the seller needs to issue the requested invoice; never the
        # buyer's customer account.
        class InvoiceRequestSerializer < V3::InvoiceRequestSerializer
          typelize billing_address: { nullable: true }

          attributes created_at: :iso8601

          one :billing_address, resource: proc { Spree.api.seller_address_serializer }
        end
      end
    end
  end
end
