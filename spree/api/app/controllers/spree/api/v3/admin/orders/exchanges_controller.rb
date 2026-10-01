module Spree
  module Api
    module V3
      module Admin
        module Orders
          # Exchanges on a completed order. Each status change is its own
          # member action, because each carries different arguments.
          class ExchangesController < BaseController
            include Spree::Api::V3::Orders::ExchangeActions

            # Exchanges are a subject of the `orders` catalog resource, so
            # `read_orders`/`write_orders` gate these endpoints. `:exchanges`
            # would name a key no catalog knows.
            scoped_resource :orders

            before_action :set_resource, only: [:show, :update, :approve, :receive, :fulfill, :cancel]

            # PATCH /api/v3/admin/orders/:order_id/exchanges/:id
            #
            # Editable fields only — status moves through the member actions.
            def update
              if @resource.update(update_attributes)
                render json: serialize_resource(@resource.reload)
              else
                render_validation_error(@resource.errors)
              end
            end

            protected

            def serializer_class
              Spree.api.admin_exchange_serializer
            end

            def collection_includes
              [:reason, :stock_location, { exchange_line_items: [:original_variant, :new_variant] }]
            end

            def permitted_params
              params.permit(:memo, :reason_id, :stock_location_id, metadata: {})
            end

            private

            # The ids are resolved through the store rather than assigned raw,
            # so another store's reason or warehouse reads as missing.
            def update_attributes
              attributes = permitted_params.to_h.except('reason_id', 'stock_location_id')

              if params.key?(:reason_id)
                attributes['reason'] =
                  (current_store.return_reasons.find_by_prefix_id!(params[:reason_id]) if params[:reason_id].present?)
              end

              if params.key?(:stock_location_id)
                attributes['stock_location'] =
                  if params[:stock_location_id].present?
                    current_store.stock_locations.accessible_by(current_ability, :show).
                      find_by_prefix_id!(params[:stock_location_id])
                  end
              end

              attributes
            end

            # The whole store's catalogue, and any warehouse the caller may
            # see: an operator exchanges into anything the store sells.
            def replacement_variant_for(variant_id)
              current_store.variants.find_by_prefix_id!(variant_id)
            end

            def stock_location_for_create
              return nil if create_params[:stock_location_id].blank?

              current_store.stock_locations.accessible_by(current_ability, :show).
                find_by_prefix_id!(create_params[:stock_location_id])
            end
          end
        end
      end
    end
  end
end
