module Spree
  module Api
    class CountriesController < Spree::Api::BaseController
      skip_before_action :check_for_user_or_api_key
      skip_before_action :authenticate_user

      def index
        @countries = Spree::Country.accessible_by(current_ability, :read).ransack(params[:q]).result.
                     includes(:states).order('name ASC').
                     page(params[:page]).per(params[:per_page])
        country = Spree::Country.order("updated_at ASC").last
        if stale?(country)
          respond_with(@countries)
        end
      end

      def show
        @country = Spree::Country.accessible_by(current_ability, :read).find(params[:id])
        respond_with(@country)
      end
    end
  end
end
