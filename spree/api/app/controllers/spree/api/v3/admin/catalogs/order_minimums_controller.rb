module Spree
  module Api
    module V3
      module Admin
        module Catalogs
          # The least a whole order must come to under a catalog's agreement.
          # One row per currency — never one amount with a currency beside
          # it, because Spree holds no exchange rates.
          class OrderMinimumsController < BaseController
            before_action :authorize_parent_access!


            protected

            def model_class
              Spree::CatalogOrderMinimum
            end

            def serializer_class
              Spree.api.admin_catalog_order_minimum_serializer
            end

            def scope
              @parent.order_minimums
            end

            def parent_association
              :order_minimums
            end

            def permitted_params
              params.permit(:currency, :amount)
            end

          end
        end
      end
    end
  end
end
