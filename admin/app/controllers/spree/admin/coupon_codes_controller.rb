module Spree
  module Admin
    class CouponCodesController < ResourceController
      belongs_to 'spree/promotion', find_by: :id

      include PromotionsBreadcrumbConcern

      def collection
        return @collection if @collection.present?

        base_collection = super

        params[:q] ||= {}
        @search = base_collection.ransack(params[:q])
        @collection = if request.format.csv?
                        @search.result
                      else
                        @pagy, result = pagy(@search.result, items: params[:per_page] || Spree::Admin::Config[:admin_records_per_page])
                        result
                      end
      end
    end
  end
end
