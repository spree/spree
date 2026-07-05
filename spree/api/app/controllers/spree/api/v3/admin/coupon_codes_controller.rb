module Spree
  module Api
    module V3
      module Admin
        # Read-only listing of coupon codes. Codes are generated server-side
        # based on the parent promotion's `code_prefix` and `number_of_codes`,
        # so this controller intentionally only exposes index/show.
        class CouponCodesController < ResourceController
          scoped_resource :promotions

          protected

          def model_class
            Spree::CouponCode
          end

          def serializer_class
            Spree.api.admin_coupon_code_serializer
          end

          def set_parent
            @parent = current_store.promotions.accessible_by(current_ability, :show)
                                   .find_by_prefix_id!(params[:promotion_id])
          end

          def parent_association
            :coupon_codes
          end
        end
      end
    end
  end
end
