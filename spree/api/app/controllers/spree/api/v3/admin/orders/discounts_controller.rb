module Spree
  module Api
    module V3
      module Admin
        module Orders
          # Typed Spree::Discount rows on an order. Manual rows have full CRUD;
          # promotion-sourced rows are read-only (recalculation owns them) and
          # respond 422 to update/destroy. Mutations re-sum the order totals —
          # this is the sanctioned post-placement discount path and works on
          # completed orders.
          class DiscountsController < BaseController
            scoped_resource :orders

            # POST /api/v3/admin/orders/:order_id/discounts
            def create
              with_order_lock do
                line_item = @parent.line_items.find_by_prefix_id!(params[:line_item_id]) if params[:line_item_id].present?

                result = Spree.order_add_manual_discount_service.call(
                  order: @parent,
                  label: params[:label],
                  value: params[:value].presence || params[:amount],
                  value_type: params[:value_type].presence || 'flat',
                  line_item: line_item
                )

                if result.success?
                  render json: { data: serialize_collection(result.value) }, status: :created
                else
                  render_error(code: ERROR_CODES[:validation_error], message: result.error.to_s, status: :unprocessable_entity)
                end
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/discounts/:id
            def update
              with_order_lock do
                result = Spree.order_discount_update_service.call(order: @parent, discount: @resource, attributes: permitted_params)

                if result.success?
                  render json: serialize_resource(@resource)
                elsif result.error.value == :promotion_discount_not_editable
                  render_promotion_row_error
                else
                  render_validation_error(@resource.errors)
                end
              end
            end

            # DELETE /api/v3/admin/orders/:order_id/discounts/:id
            def destroy
              with_order_lock do
                result = Spree.order_discount_destroy_service.call(order: @parent, discount: @resource)

                if result.success?
                  head :no_content
                else
                  render_promotion_row_error
                end
              end
            end

            protected

            def model_class
              Spree::Discount
            end

            def serializer_class
              Spree.api.admin_discount_serializer
            end

            def scope
              @parent.discounts
            end

            def permitted_params
              params.permit(:label, :amount)
            end

            def collection_includes
              [:promotion, :line_item, :fulfillment]
            end

            private

            def render_promotion_row_error
              render_error(
                code: ERROR_CODES[:discount_not_editable],
                message: Spree.t('errors.messages.promotion_discount_not_editable'),
                status: :unprocessable_entity
              )
            end
          end
        end
      end
    end
  end
end
