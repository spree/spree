module Spree
  module Admin
    class CouponCodesController < ResourceController
      belongs_to 'spree/promotion', find_by: :id

      include PromotionsBreadcrumbConcern

      def collection
        return @collection if @collection.present?

        @collection = super

        params[:q] ||= {}
        @search = @collection.ransack(params[:q])
        @collection = if request.format.csv?
                        @search.result
                      else
                        @search.result.page(params[:page])
                      end
      end
    end
  end
end
