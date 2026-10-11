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

            request_params :exchange do |body|
              body.attribute :items, :array,
                required: true, on: :create,
                only: :create,
                description: 'Items coming back, and what goes out in their place.' do |item|
                item.attribute :fulfillment_item_id, :id, required: true
                item.attribute :new_variant_id, :id, required: true
                item.attribute :quantity, :integer, required: true
              end
              body.attribute :stock_location_id, :id, description: 'Where the goods come back to.'
              body.attribute :reason_id, :id, description: "One of the store's return reasons."
              body.attribute :memo, :string
              body.attribute :metadata, :hash, only: :update
            end

            request_params 'ExchangeReceiveParams', action: :receive do |body|
              body.attribute :items, :array,
                description: 'What actually arrived. Omit to receive everything as requested and resellable.' do |item|
                item.attribute :exchange_line_item_id, :id, required: true
                item.attribute :quantity, :integer, required: true
                item.attribute :resellable, :boolean,
                  description: 'Goods that cannot be resold are received but never restocked. Defaults to true.'
              end
            end

            request_params 'ExchangeFulfillParams', action: :fulfill do |body|
              body.attribute :refund_method, :string,
                choices: Spree::RefundMethods::METHODS,
                description: 'How a credit is returned when the replacements cost less than what came back. Defaults to `store_credit`. A balance the customer owes is left for the merchant to collect.'
            end

            request_params 'ExchangeCancelParams', action: :cancel do |body|
              body.attribute :reason, :string, description: 'A note on why the exchange was canceled.'
            end

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
              params.permit(*permitted_attributes)
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
