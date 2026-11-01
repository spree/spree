module Spree
  module Api
    module V3
      module Admin
        # Every invoice in the store — what an accountant exports. Created
        # under the order or seller payout it belongs to; here it is read,
        # downloaded, sent again, or deleted while it is an unsent upload.
        class InvoicesController < ResourceController
          include Spree::Api::V3::InvoiceMemberActions

          scoped_resource :orders

          protected

          def serializer_class
            Spree.api.admin_invoice_serializer
          end
        end
      end
    end
  end
end
