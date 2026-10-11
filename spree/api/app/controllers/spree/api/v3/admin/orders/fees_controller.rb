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

            request_params :fee do
              string :label, required: :create, example: 'Gift wrap'
              decimal :amount, required: :create, example: '4.00'
              string :kind, enum: Spree::Fee::KINDS, example: 'gift_wrap', description: 'Defaults to `surcharge`.'
              # Resolved through the order by the controller, never assigned.
              id :line_item_id, :fulfillment_id, only: :create, nullable: true, permit: false,
                                                 description: 'The line item or fulfillment the fee belongs to. Omitted, the fee is order-level.'
            end

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
              params.permit(*permitted_attributes)
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
