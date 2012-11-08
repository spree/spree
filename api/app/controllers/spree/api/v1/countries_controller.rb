module Spree
  module Api
    module V1
      class CountriesController < Spree::Api::V1::BaseController
        def index
          @countries = Country.ransack(params[:q]).result.includes(:states).order('name ASC')
        end

        def show
          @country = Country.find(params[:id])
        end
      end
    end
  end
end
