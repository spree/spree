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

            # PUT /api/v3/admin/catalogs/:catalog_id/order_minimums
            #
            # { order_minimums: [{ currency: 'USD', amount: '500.00' }] }
            #
            # Replaces the whole set: a currency absent from the payload has
            # its minimum lifted. One request per save, because the agreement
            # editor stages every term behind the catalog's Save and a
            # half-applied set is not a state to leave a merchant in.
            def replace
              authorize! :update, @catalog

              result = Spree::Catalogs::SetOrderMinimums.call(
                catalog: @catalog, order_minimums: minimum_params
              )

              if result.success?
                render json: { data: serialize_collection(@catalog.order_minimums.reload) }
              else
                render_service_error(result)
              end
            end

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

            private

            def minimum_params
              Array(params[:order_minimums]).map do |row|
                row.permit(:currency, :amount).to_h.symbolize_keys
              end
            end
          end
        end
      end
    end
  end
end
