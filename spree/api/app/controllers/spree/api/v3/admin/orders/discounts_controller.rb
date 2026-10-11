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

                value_type = params[:value_type].presence || 'flat'
                value_name = params[:value].present? ? :value : :amount
                # A flat discount is money in the order's currency; a percentage is a rate.
                value = value_type == 'percent' ? decimal_param(value_name) : money_param(value_name, @parent.currency)

                result = Spree.order_discount_create_service.call(
                  order: @parent,
                  label: params[:label],
                  value: value,
                  value_type: value_type,
                  line_item: line_item
                )

                if result.success?
                  render json: { data: serialize_collection(result.value) }, status: :created
                else
                  render_error(code: ERROR_CODES[:validation_error], message: result.error.to_s, status: :unprocessable_content)
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
                message: I18n.t('spree.errors.messages.promotion_discount_not_editable'),
                status: :unprocessable_content
              )
            end
          end
        end
      end
    end
  end
end
