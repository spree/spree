module Spree
  module Api
    class CountriesController < Spree::Api::BaseController

      def index
        @countries = Country.accessible_by(current_ability, :read).ransack(params[:q]).result.
                     includes(:states).order('name ASC').
                     page(params[:page]).per(params[:per_page])

        respond_with(@countries)
      end

      def show
        @country = Country.accessible_by(current_ability, :read).find(params[:id])
        respond_with(@country)
      end
    end
  end
end
