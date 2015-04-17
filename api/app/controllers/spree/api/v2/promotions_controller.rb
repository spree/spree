module Spree
  module Api
    module V2
      class PromotionsController < Spree::Api::BaseController
        before_filter :requires_admin
        before_filter :load_promotion

        def show
          if @promotion
            render json: @promotion
          else
            raise ActiveRecord::RecordNotFound
          end
        end

        private
          def requires_admin
            return if @current_user_roles.include?("admin")
            unauthorized and return
          end

          def load_promotion
            @promotion = Spree::Promotion.find_by_id(params[:id]) || Spree::Promotion.with_coupon_code(params[:id])
          end
      end
    end
  end
end
