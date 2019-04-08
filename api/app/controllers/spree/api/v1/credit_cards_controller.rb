module Spree
  module Api
    module V1
      class CreditCardsController < Spree::Api::BaseController
        before_action :user

        def index
          @credit_cards = user.
                          credit_cards.
                          accessible_by(current_ability).
                          with_payment_profile.
                          ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
          respond_with(@credit_cards)
        end

        private

        def user
          if params[:user_id].present?
            @user ||= Spree.user_class.accessible_by(current_ability, :show).find(params[:user_id])
          end
        end
      end
    end
  end
end
