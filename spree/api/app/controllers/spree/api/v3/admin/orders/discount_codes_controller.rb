module Spree
  module Api
    module V3
      module Admin
        module Orders
          # Applies/removes a discount code on a draft order — the admin
          # counterpart of the storefront cart endpoint, with the same pending
          # semantics: a real-but-not-yet-eligible code is kept and activates
          # on the first recalculation where the order qualifies. Completed
          # orders are frozen; their discounts change only through manual rows
          # (see DiscountsController).
          class DiscountCodesController < BaseController
            skip_before_action :set_resource, raise: false

            # POST /api/v3/admin/orders/:order_id/discount_codes
            def create
              with_order_lock do
                return render_completed_order_error if @parent.completed?

                @parent.coupon_code = permitted_params[:code]

                coupon_handler.apply

                if coupon_handler.successful? || pending_eligibility?
                  @parent.save!(validate: false) if @parent.changed?
                  render json: serialize_resource(@parent.reload), status: :created
                else
                  @parent.update_column(:coupon_code, nil) if @parent.read_attribute(:coupon_code).present?
                  render_errors(coupon_handler.error)
                end
              end
            end

            # DELETE /api/v3/admin/orders/:order_id/discount_codes/:id
            # :id is the discount code string.
            def destroy
              with_order_lock do
                return render_completed_order_error if @parent.completed?

                coupon_handler.remove(params[:id])

                if coupon_handler.successful?
                  render json: serialize_resource(@parent.reload)
                else
                  render_errors(coupon_handler.error)
                end
              end
            end

            protected

            def model_class
              Spree::Order
            end

            def serializer_class
              Spree.api.admin_order_serializer
            end

            private

            def coupon_handler
              @coupon_handler ||= Spree.coupon_handler.new(@parent, enable_gift_cards: false)
            end

            def pending_eligibility?
              coupon_handler.status_code == :coupon_code_not_eligible
            end

            def render_completed_order_error
              render_error(
                code: ERROR_CODES[:discount_not_editable],
                message: Spree.t('errors.messages.coupon_code_frozen_after_completion'),
                status: :unprocessable_content
              )
            end

            def permitted_params
              params.permit(:code)
            end
          end
        end
      end
    end
  end
end
