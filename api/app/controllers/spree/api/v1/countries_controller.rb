module Spree
  module Api
    module V1
      class CountriesController < Spree::Api::BaseController
        def index
          @countries = Country.ransack(params[:q]).result.includes(:states).order('name ASC')
            .page(params[:page]).per(params[:per_page])
        end

        def show
          @country = Country.find(params[:id])
        end
      end
    end
  end
end
