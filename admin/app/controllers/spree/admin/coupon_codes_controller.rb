module Spree
  module Admin
    class CouponCodesController < ResourceController
      belongs_to 'spree/promotion', find_by: :id

      include PromotionsBreadcrumbConcern
    end
  end
end
