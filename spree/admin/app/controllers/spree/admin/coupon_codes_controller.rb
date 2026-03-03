module Spree
  module Admin
    class CouponCodesController < ResourceController
      belongs_to 'spree/promotion', find_by: :prefix_id

      include PromotionsBreadcrumbConcern

      def index
        params[:q] ||= {}
        params[:q][:promotion_id_eq] ||= parent.id
        super
      end
    end
  end
end
