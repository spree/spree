module Spree
  module Admin
    class CouponCodesController < ResourceController
      belongs_to 'spree/promotion', find_by: :prefix_id

      include PromotionsBreadcrumbConcern
    end
  end
end
