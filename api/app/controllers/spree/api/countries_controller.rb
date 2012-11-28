module Spree
  module Api
    class CountriesController < Spree::Api::BaseController
      respond_to :json

      def index
        @countries = Country.ransack(params[:q]).result.includes(:states).order('name ASC')
          .page(params[:page]).per(params[:per_page])
        respond_with(@countries)
      end

      def show
        @country = Country.find(params[:id])
        respond_with(@country)
      end
    end
  end
end
