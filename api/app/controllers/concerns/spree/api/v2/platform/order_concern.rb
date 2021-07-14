module Spree
  module Api
    module V2
      module Platform
        module OrderConcern
          private

          def render_order(result)
            if result.success?
              render_serialized_payload { serialized_current_order }
            else
              render_error_payload(result.error)
            end
          end

          def ensure_order
            raise ActiveRecord::RecordNotFound if spree_order.nil?
          end

          def spree_order
            @spree_order ||= load_order_with_lock
          end

          def load_order(lock: false)
            scope.lock(lock).find_by!(number: params[:id])
          end

          def load_order_with_lock
            load_order(lock: true)
          end

          def serialized_current_order
            serialize_resource(spree_order)
          end

          def load_variant
            @variant = Spree::Variant.find(params[:variant_id])
          end

          def load_user
            @user = if params[:user_id]
                      Spree::User.find(params[:user_id])
                    end
          end

          def line_item
            @line_item ||= spree_order.line_items.find(params[:line_item_id])
          end

          def set_order_currency
            @currency = if params[:currency] && current_store.supported_currencies_list.include?(params[:currency])
                          params[:currency]
                        else
                          current_currency
                        end
          end

          def select_coupon_codes
            params[:coupon_code].present? ? [params[:coupon_code]] : check_coupon_codes
          end

          def check_coupon_codes
            spree_order.promotions.coupons.map(&:code)
          end

          def select_error(coupon_codes)
            result = coupon_handler.new(spree_order).remove(coupon_codes.first)
            result.error
          end

          def select_errors(coupon_codes)
            results = []
            coupon_codes.each do |coupon_code|
              results << coupon_handler.new(spree_order).remove(coupon_code)
            end

            results.select(&:error)
          end

          def render_error_item_quantity
            render json: { error: I18n.t(:wrong_quantity, scope: 'spree.api.v2.cart') }, status: 422
          end
        end
      end
    end
  end
end
