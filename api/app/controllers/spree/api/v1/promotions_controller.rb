module Spree
  module Api
    module V1
      class PromotionsController < Spree::Api::BaseController
        before_action :requires_admin
        before_action :load_promotion

        def show
          if @promotion
            respond_with(@promotion, default_template: :show)
          else
            raise ActiveRecord::RecordNotFound
          end
        end

        private

        def requires_admin
          return if @current_user_roles.include?('admin')

          unauthorized and return
        end

        def load_promotion
          @promotion = Spree::Promotion.find_by(id: params[:id]) || Spree::Promotion.with_coupon_code(params[:id])
        end
      end
    end
  end
end
