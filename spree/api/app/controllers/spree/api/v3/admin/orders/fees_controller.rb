module Spree
  module Api
    module V3
      module Admin
        module Orders
          # Typed Spree::Fee rows (surcharge, handling, gift wrap, COD).
          # Full CRUD — all fee rows are admin-managed. Order-level when no
          # line_item/fulfillment target is given. Mutations re-sum the order
          # totals and work on completed orders (sanctioned post-placement
          # edit path).
          class FeesController < BaseController
            scoped_resource :orders

            # POST /api/v3/admin/orders/:order_id/fees
            def create
              with_order_lock do
                result = Spree.order_fee_create_service.call(order: @parent, attributes: permitted_params.merge(target_attributes))

                if result.success?
                  render json: serialize_resource(result.value), status: :created
                else
                  render_validation_error(result.value.errors)
                end
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/fees/:id
            def update
              with_order_lock do
                result = Spree.order_fee_update_service.call(order: @parent, fee: @resource, attributes: permitted_params)

                if result.success?
                  render json: serialize_resource(@resource)
                else
                  render_validation_error(@resource.errors)
                end
              end
            end

            # DELETE /api/v3/admin/orders/:order_id/fees/:id
            def destroy
              with_order_lock do
                Spree.order_fee_destroy_service.call(order: @parent, fee: @resource)
                head :no_content
              end
            end

            protected

            def model_class
              Spree::Fee
            end

            def serializer_class
              Spree.api.admin_fee_serializer
            end

            def scope
              @parent.fees
            end

            def permitted_params
              params.permit(:label, :amount, :kind)
            end

            def collection_includes
              [:line_item, :fulfillment]
            end

            private

            def target_attributes
              attributes = {}
              attributes[:line_item] = @parent.line_items.find_by_prefix_id!(params[:line_item_id]) if params[:line_item_id].present?
              attributes[:fulfillment] = @parent.fulfillments.find_by_prefix_id!(params[:fulfillment_id]) if params[:fulfillment_id].present?
              attributes
            end
          end
        end
      end
    end
  end
end
