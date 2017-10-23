module Spree
  module Admin
    class PromotionCodesController < Spree::Admin::BaseController
      require 'csv'

      def index
        @promotion = Spree::Promotion.accessible_by(current_ability, :read).find(params[:promotion_id])

        respond_to do |format|
          format.csv do
            filename = "promotion-code-list-#{@promotion.id}.csv"
            headers["Content-Type"] = "text/csv"
            headers["Content-disposition"] = "attachment; filename=\"#{filename}\""
          end
        end
      end

    end
  end
end
