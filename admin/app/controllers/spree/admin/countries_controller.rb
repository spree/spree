module Spree
  module Admin
    class CountriesController < Spree::Admin::BaseController
      def select_options
        search_params = params[:q].is_a?(String) ? { name_cont: params[:q] } : params[:q]
        countries = Spree::Country.ransack(search_params).result.order(:name).limit(50)

        render json: countries.pluck(:id, :name).map { |id, name| { id: id, name: name } }
      end
    end
  end
end
