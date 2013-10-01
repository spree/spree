module Spree
  module Api
    class CountriesController < Spree::Api::BaseController
      skip_before_filter :check_for_user_or_api_key
      skip_before_filter :authenticate_user

      def index
        @countries = Country.ransack(params[:q]).result.
                     includes(:states).order('name ASC').
                     page(params[:page]).per(params[:per_page])

        respond_with(@countries)
      end

      def show
        @country = Country.find(params[:id])
        respond_with(@country)
      end
    end
  end
end
