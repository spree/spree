module Spree
  module Api
    module V3
      module Admin
        module Orders
          # The registration the order was taxed against, frozen at completion.
          # Read-only because the row is: staff investigating why an invoice was
          # zero-rated need to see the number and the verdict behind it, not
          # change what the invoice already says.
          class TaxIdentifiersController < BaseController
            # A singular nested resource: there is no :id to look up, and the
            # inherited lookup would reach for a plural association that does
            # not exist. Mirrors Orders::StoreCreditsController.
            skip_before_action :set_resource, raise: false

            scoped_resource :orders

            # GET /api/v3/admin/orders/:order_id/tax_identifier
            def show
              return head :not_found if @parent.tax_identifier.nil?

              authorize_resource!(@parent.tax_identifier, :show)

              render json: serialize_resource(@parent.tax_identifier)
            end

            protected

            def model_class
              Spree::TaxIdentifier
            end

            def serializer_class
              Spree.api.admin_tax_identifier_serializer
            end
          end
        end
      end
    end
  end
end
